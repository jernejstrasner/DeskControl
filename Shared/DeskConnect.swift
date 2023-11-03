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
    private var characteristicPosition: CBCharacteristic!
    private var characteristicControl: CBCharacteristic!
    
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
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    func connect(desk: Desk) {
        logger.info("Connecting to \(desk.name)")
        if let peripheral = self.peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }

        let peripherals = self.centralManager.retrievePeripherals(withIdentifiers: [desk.id])
        guard let peripheral = peripherals.first else {
            logger.error("Can't find desk \(desk.name)")
            return
        }
        self.peripheral = peripheral
        self.peripheral!.delegate = self
        isConnecting = true
        self.centralManager.connect(peripheral)
    }
    
    private var discoveryHandle: DispatchWorkItem? = nil
    
    func startDiscovery(timeout: DispatchTimeInterval = .seconds(15)) {
        if isScanning {
            return
        }
        isScanning = true
        #if DEBUG
        centralManager.scanForPeripherals(withServices: nil)
        #else
        // This only works for devices that are actively advertising the service aka. pairing mode
        centralManager.scanForPeripherals(withServices: [DeskServices.control, DeskServices.referenceOutput])
        #endif
        discoveryHandle = DispatchWorkItem { [weak self] in
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
        if central.state != .poweredOn {
            logger.error("Bluetooth not powered on: \(String(describing: central.state))")
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
        logger.info("Connected to \(peripheral.name!)")
        self.isConnecting = false
        if let desk = Desk(peripheral: peripheral) {
            self.connectedDesk = desk
            peripheral.discoverServices([DeskServices.control, DeskServices.referenceOutput])
        } else {
            logger.error("Invalid desk connected. Not a desk?")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Failed to connect to \(peripheral.name!)")
        self.peripheral = nil
        self.isConnecting = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("Disconnected \(peripheral.name!)")
        self.peripheral = nil
        self.currentPosition = nil
        self.connectedDesk = nil
        self.isConnecting = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, timestamp: CFAbsoluteTime, isReconnecting: Bool, error: Error?) {
        logger.info("Disconnected \(peripheral.name!). Reconnecting: \(isReconnecting)")
        self.peripheral = nil
        self.currentPosition = nil
        self.connectedDesk = nil
        self.isConnecting = false
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
    }
    
    /// Peripheral value updates
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let value = characteristic.value, characteristic.uuid == DeskServices.referenceOutputCharacteristicPosition {
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
            } catch let e {
                logger.error("Error unpacking position: \(e)")
            }
        }
    }
    
    /// Peripheral commands
    
    func wakeUp() {
        self.peripheral?.writeValue(DeskServices.valueWakeUp, for: self.characteristicControl, type: .withResponse)
    }
    
    func stopMoving() {
        moveTimer?.cancel()
        moveTimer = nil
        status = .idle
        self.peripheral?.writeValue(DeskServices.valueStopMove, for: self.characteristicControl, type: .withResponse)
    }
    
    enum Direction {
        case up, down
    }
    
    func move(_ direction: Direction, continuously: Bool = false) {
        // If we haven't fetched the current position yet then make it a no-op
        if currentPosition == nil {
            return
        }
        
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
                if let self = self {
                    self.peripheral?.writeValue(command, for: self.characteristicControl, type: .withoutResponse)
                }
            }
            timer.schedule(deadline: .now(), repeating: .milliseconds(700))
            timer.resume()
            moveTimer = timer
        } else {
            self.peripheral?.writeValue(command, for: self.characteristicControl, type: .withoutResponse)
        }
    }

    /**
     Moving to a specific position requires to send command to the desk in a loop.
     The desk controller does not have direct support for moving to a specific position continously.
     */
    func move(to position: Int) {
        // If we don't have a current position yet or we are trying to move to same position
        // TODO: Approximate comparison, we'll never been completely precise here
        guard let currentPosition = self.currentPosition, currentPosition != position else {
            return
        }
        
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
            if let self = self {
                self.peripheral?.writeValue(command, for: self.characteristicControl, type: .withoutResponse)
            }
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
