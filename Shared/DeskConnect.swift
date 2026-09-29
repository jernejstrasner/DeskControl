//
//  Connect.swift
//  desk
//
//  Created by Forti on 05/06/2020.
//  Copyright © 2020 Forti. All rights reserved.
//

import Foundation
import CoreBluetooth
import OSLog
import Sentry
#if os(iOS)
import UIKit
#endif

struct Desk: Identifiable, Hashable {
    let id: UUID
    let name: String
}

extension Desk {
    init?(peripheral: CBPeripheral) {
        guard let name = peripheral.name else {
            return nil
        }
        self.name = name
        self.id = peripheral.identifier
    }
}

class DeskConnect: NSObject, CBPeripheralDelegate, CBCentralManagerDelegate, ObservableObject {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristicPosition: CBCharacteristic?
    private var characteristicControl: CBCharacteristic?

    private var moveTimer: DispatchSourceTimer? = nil

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DeskConnect")

    private enum Status {
        case idle
        case movingUp(Int?)
        case movingDown(Int?)
    }
    private var status = Status.idle

    @Published var centralState: CBManagerState = .unknown
    @Published var discoveredDesks: Set<Desk> = []
    @Published var currentPosition: Int? = nil
    @Published var currentSpeed: Int = 0
    @Published var connectedDesk: Desk? = nil
    @Published var isScanning: Bool = false
    @Published var isConnecting: Bool = false
    @Published var errorMessage: String? = nil

    /// When true, automatically re-issue a connect after unexpected disconnection
    private var shouldAutoReconnect = false

    private var backgroundTimer: DispatchSourceTimer? = nil
    #if os(iOS)
    private var backgroundObserver: NSObjectProtocol? = nil
    private var foregroundObserver: NSObjectProtocol? = nil
    private var taskID = UIBackgroundTaskIdentifier.invalid
    #elseif os(macOS)
    private var wakeObserver: NSObjectProtocol? = nil
    #endif
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)

        #if os(macOS)
        // Reconnect after macOS wakes from sleep — CoreBluetooth can silently
        // drop pending connects during sleep without reporting a state change.
        // NSWorkspace notifications are posted on NSWorkspace.shared.notificationCenter,
        // not the default center.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            guard self.shouldAutoReconnect,
                  self.centralManager.state == .poweredOn,
                  self.connectedDesk == nil,
                  let peripheral = self.peripheral else { return }
            self.logger.info("Reconnecting after wake")
            self.centralManager.connect(peripheral)
        }
        #elseif os(iOS)
        // Set a 10s timer when app goes to background to disconnect
        backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] notification in
            let timer = DispatchSource.makeTimerSource(queue: .main)
            self?.taskID = UIApplication.shared.beginBackgroundTask(withName: "Bluetooth Timeout", expirationHandler: { [weak self] in
                timer.cancel()
                if let tid = self?.taskID {
                    UIApplication.shared.endBackgroundTask(tid)
                    self?.taskID = .invalid
                }
            })

            timer.setEventHandler { [weak self] in
                self?.shouldAutoReconnect = false
                self?.stopDiscovery()
                if let peripheral = self?.peripheral {
                    self?.centralManager.cancelPeripheralConnection(peripheral)
                }
                if let tid = self?.taskID {
                    UIApplication.shared.endBackgroundTask(tid)
                    self?.taskID = .invalid
                }
            }
            timer.schedule(deadline: .now() + .seconds(10))
            timer.resume()
            self?.backgroundTimer = timer
        }
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main, using: { [weak self] notification in
            if let timer = self?.backgroundTimer {
                timer.cancel()
                self?.backgroundTimer = nil
            }
        })
        #endif
    }

    deinit {
        #if os(macOS)
        if let wo = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wo)
        }
        #elseif os(iOS)
        if let bo = backgroundObserver {
            NotificationCenter.default.removeObserver(bo)
        }
        if let fo = foregroundObserver {
            NotificationCenter.default.removeObserver(fo)
        }
        #endif
        backgroundTimer?.cancel()
    }


    func connect(desk: Desk) {
        logger.info("Connecting to \(desk.name)")
        shouldAutoReconnect = false
        if let peripheral = self.peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }

        let peripherals = self.centralManager.retrievePeripherals(withIdentifiers: [desk.id])
        guard let peripheral = peripherals.first else {
            logger.error("Can't find desk \(desk.name)")
            isConnecting = false
            errorMessage = "Desk not found. Try scanning again"
            return
        }
        self.peripheral = peripheral
        peripheral.delegate = self
        isConnecting = true
        shouldAutoReconnect = true
        self.centralManager.connect(peripheral)
    }

    func stopConnecting() {
        shouldAutoReconnect = false
        if let peripheral = self.peripheral {
            logger.info("Disconnecting \(peripheral.name ?? "unknown")")
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    private var discoveryHandle: DispatchWorkItem? = nil

    func startDiscovery(timeout: DispatchTimeInterval = .seconds(15)) {
        if isScanning {
            return
        }
        isScanning = true
        // This only works for devices that are actively advertising the service aka. pairing mode
        centralManager.scanForPeripherals(withServices: [DeskServices.control, DeskServices.referenceOutput])
        discoveryHandle = DispatchWorkItem { [weak self] in
            if self?.discoveredDesks.isEmpty == true {
                self?.errorMessage = "No desks found nearby"
            }
            self?.stopDiscovery()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: discoveryHandle!)
    }

    func stopDiscovery() {
        discoveryHandle?.cancel()
        centralManager.stopScan()
        isScanning = false
    }

    /// Bluetooth module state updates

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralState = central.state
        if central.state == .poweredOn {
            // Clear any BT-state errors now that we're back
            errorMessage = nil
        } else {
            logger.error("Bluetooth not powered on: \(String(describing: central.state))")
            // Clear stale references — peripheral objects become invalid when BT powers off.
            // ContentView's onChange(of: centralState) will reconnect when BT comes back.
            self.peripheral = nil
            self.currentPosition = nil
            self.connectedDesk = nil
            self.isConnecting = false

            switch central.state {
            case .poweredOff:
                errorMessage = "Bluetooth is turned off"
            case .unauthorized:
                errorMessage = "Bluetooth permission denied"
            case .unsupported:
                errorMessage = "Bluetooth is not supported on this device"
            default:
                break
            }
        }
    }

    /// Peripheral discovery

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let desk = Desk(peripheral: peripheral) {
            self.discoveredDesks.insert(desk)
        }
    }

    /// Peripheral connection

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Connected to \(peripheral.name ?? "unknown")")
        self.errorMessage = nil
        peripheral.discoverServices([DeskServices.control, DeskServices.referenceOutput])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Failed to connect to \(peripheral.name ?? "unknown")")
        self.peripheral = nil
        self.isConnecting = false
        self.shouldAutoReconnect = false
        errorMessage = "Failed to connect to \(peripheral.name ?? "desk")"
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Ignore stale disconnects (e.g. old peripheral when switching desks)
        guard peripheral.identifier == self.peripheral?.identifier else { return }

        logger.info("Disconnected \(peripheral.name ?? "unknown")")
        self.currentPosition = nil
        self.connectedDesk = nil
        self.characteristicControl = nil
        self.characteristicPosition = nil
        self.isConnecting = false

        if shouldAutoReconnect && central.state == .poweredOn {
            // Pend a reconnect — CoreBluetooth will connect when the peripheral is available
            peripheral.delegate = self
            self.peripheral = peripheral
            centralManager.connect(peripheral)
        } else {
            self.peripheral = nil
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, timestamp: CFAbsoluteTime, isReconnecting: Bool, error: Error?) {
        // Ignore stale disconnects (e.g. old peripheral when switching desks)
        guard peripheral.identifier == self.peripheral?.identifier else { return }

        logger.info("Disconnected \(peripheral.name ?? "unknown"). Reconnecting: \(isReconnecting)")
        self.currentPosition = nil
        self.connectedDesk = nil
        self.characteristicControl = nil
        self.characteristicPosition = nil
        self.isConnecting = false

        if isReconnecting {
            // System is handling reconnection, keep peripheral reference
            return
        }

        if shouldAutoReconnect && central.state == .poweredOn {
            peripheral.delegate = self
            self.peripheral = peripheral
            centralManager.connect(peripheral)
        } else {
            self.peripheral = nil
        }
    }

    /// Peripheral services

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics(DeskServices.characteristicsForService(id: service.uuid), for: service)
            }
        }
    }

    /// Peripheral characteristics

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)

                if (characteristic.uuid == DeskServices.controlCharacteristic) {
                    self.characteristicControl = characteristic
                }

                if (characteristic.uuid == DeskServices.referenceOutputCharacteristicPosition) {
                    self.characteristicPosition = characteristic
                }
            }
        }

        // Only mark as connected once we have both characteristics ready
        if self.characteristicControl != nil, self.characteristicPosition != nil, self.connectedDesk == nil {
            self.isConnecting = false
            if let desk = Desk(peripheral: peripheral) {
                self.connectedDesk = desk
            }
        }
    }

    /// Peripheral value updates

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let value = characteristic.value, characteristic.uuid == DeskServices.referenceOutputCharacteristicPosition {
            let transaction = SentrySDK.startTransaction(name: "Update position", operation: "bluetooth")
            do {
                let unpacked = try unpack("<Hh", value[..<4])

                let position = unpacked[0] as! Int
                currentPosition = DeskServices.baseHeight + position

                let speed = unpacked[1] as! Int
                currentSpeed = speed

                // Check if safety stop was triggered by the desk
                switch self.status {
                case .movingUp(_) where speed == 0, .movingDown(_) where speed == 0:
                    self.stopMoving()
                default:
                    break
                }

                // If we're moving to target then check if we need to stop here
                // Take speed into account so we don't overshoot
                let stopFactor = abs(currentSpeed) / 100
                if case .movingUp(.some(let target)) = status, currentPosition! >= target - stopFactor {
                    stopMoving()
                } else if case .movingDown(.some(let target)) = status, currentPosition! <= target + stopFactor {
                    stopMoving()
                }

                transaction.finish()
            } catch let e {
                logger.error("Error unpacking position: \(e)")
                transaction.finish(status: .internalError)
            }
        }
    }

    /// Peripheral commands

    func wakeUp() {
        guard let characteristicControl else { return }
        self.peripheral?.writeValue(DeskServices.valueWakeUp, for: characteristicControl, type: .withResponse)
    }

    func stopMoving() {
        if isScanning || isConnecting { return }
        moveTimer?.cancel()
        moveTimer = nil
        status = .idle
        guard let characteristicControl else { return }
        self.peripheral?.writeValue(DeskServices.valueStopMove, for: characteristicControl, type: .withResponse)
    }

    enum Direction {
        case up, down
    }

    func move(_ direction: Direction, continuously: Bool = false) {
        guard currentPosition != nil, let characteristicControl else { return }

        // If we're currently moving stop it
        stopMoving()

        // Set state
        let command: Data
        switch direction {
        case .up:
            status = .movingUp(nil)
            command = DeskServices.valueMoveUp
        case .down:
            status = .movingDown(nil)
            command = DeskServices.valueMoveDown
        }

        if continuously {
            let timer = DispatchSource.makeTimerSource()
            timer.setEventHandler { [weak self] in
                guard let self, let ctl = self.characteristicControl else { return }
                self.peripheral?.writeValue(command, for: ctl, type: .withoutResponse)
            }
            timer.schedule(deadline: .now(), repeating: .milliseconds(700))
            timer.resume()
            moveTimer = timer
        } else {
            self.peripheral?.writeValue(command, for: characteristicControl, type: .withoutResponse)
        }
    }

    /**
     Moving to a specific position requires to send command to the desk in a loop.
     The desk controller does not have direct support for moving to a specific position continously.
     */
    func move(to position: Int) {
        // The motor can't stop instantly so presets are only ever reached approximately;
        // skip tiny moves that would just overshoot back and forth.
        guard let currentPosition = self.currentPosition,
              abs(currentPosition - position) > DeskServices.positionTolerance,
              self.characteristicControl != nil else { return }

        // Stop in case we're moving
        stopMoving()

        // Determine direction
        let direction: Direction = position > currentPosition ? .up : .down
        let command: Data
        switch direction {
        case .up:
            status = .movingUp(position)
            command = DeskServices.valueMoveUp
        case .down:
            status = .movingDown(position)
            command = DeskServices.valueMoveDown
        }

        // Initiate the timer loop
        let timer = DispatchSource.makeTimerSource()
        timer.setEventHandler { [weak self] in
            guard let self, let ctl = self.characteristicControl else { return }
            self.peripheral?.writeValue(command, for: ctl, type: .withoutResponse)
        }
        timer.schedule(deadline: .now(), repeating: .milliseconds(700))
        timer.resume()
        moveTimer = timer
    }

}

extension Desk: RawRepresentable {
    init?(rawValue: String) {
        let parts = rawValue.split(separator: "|")
        guard parts.count == 2, let id = UUID(uuidString: String(parts[0])) else {
            return nil
        }
        self.id = id
        self.name = String(parts[1])
    }

    var rawValue: String {
        "\(id.uuidString)|\(name)"
    }
}
