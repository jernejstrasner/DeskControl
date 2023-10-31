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

protocol DeskConnectDelegate {
    func deskConnectReady()
    func deskDiscovered(name: String, identifier: UUID)
    func deskConnected(name: String, identifier: UUID)
    func deskFailedToConnect(name: String, identifier: UUID)
    func deskDisconnected(name: String, identifier: UUID)
    func deskPositionChanged(position: Int)
}

class DeskConnect: NSObject, CBPeripheralDelegate, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    
    private var characteristicPosition: CBCharacteristic!
    private var characteristicControl: CBCharacteristic!
    
    private var moveTimer: DispatchSourceTimer? = nil
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DeskConnect")
    
    private enum Status {
        case idle
        case movingUp(Int)
        case movingDown(Int)
    }
    private var status = Status.idle
    
    private var discoveredDesks: [UUID: CBPeripheral] = [:]
    
    var delegate: DeskConnectDelegate?
    
    var currentPosition: Int? = nil {
        didSet {
            if let val = currentPosition {
                self.delegate?.deskPositionChanged(position: val)
            }
        }
    }
    var currentSpeed: Int = 0
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    func connect(desk: Desk) {
        logger.info("Connecting to \(desk.name)")
        if let peripheral = self.peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            self.peripheral = nil
        }
        if let peripheral = self.discoveredDesks[desk.id] {
            self.peripheral = peripheral
            self.peripheral!.delegate = self
            self.centralManager.connect(peripheral)
        } else {
            let peripherals = self.centralManager.retrievePeripherals(withIdentifiers: [desk.id])
            guard let peripheral = peripherals.first else {
                logger.error("Can't find desk \(desk.name)")
                return
            }
            self.peripheral = peripheral
            self.peripheral!.delegate = self
            self.centralManager.connect(peripheral)
        }
    }
    
    func startDiscovery() {
        #if DEBUG
        centralManager.scanForPeripherals(withServices: nil)
        #else
        // This only works for devices that are actively advertising the service aka. pairing mode
        centralManager.scanForPeripherals(withServices: [DeskServices.control, DeskServices.referenceOutput])
        #endif
    }
    
    func stopDiscovery() {
        centralManager.stopScan()
    }
    
    var isScanning: Bool {
        centralManager.isScanning
    }
    
    /// Bluetooth module state updates
     
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            // TODO: Handle different states
            logger.error("Bluetooth not powered on: \(String(describing: central.state))")
        } else {
            delegate?.deskConnectReady()
        }
    }
    
    /// Peripheral discovery

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let deviceName = peripheral.name, self.discoveredDesks[peripheral.identifier] == nil {
            self.discoveredDesks[peripheral.identifier] = peripheral
            self.delegate?.deskDiscovered(name: deviceName, identifier: peripheral.identifier)
        }
    }
    
    /// Peripheral connection
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Connected to \(peripheral.name!)")
        self.delegate?.deskConnected(name: peripheral.name!, identifier: peripheral.identifier)
        peripheral.discoverServices([DeskServices.control, DeskServices.referenceOutput])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.info("Failed to connect to \(peripheral.name!)")
        self.peripheral = nil
        self.delegate?.deskFailedToConnect(name: peripheral.name!, identifier: peripheral.identifier)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("Disconnected \(peripheral.name!)")
        self.peripheral = nil
        self.currentPosition = nil
        self.delegate?.deskDisconnected(name: peripheral.name!, identifier: peripheral.identifier)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, timestamp: CFAbsoluteTime, isReconnecting: Bool, error: Error?) {
        logger.info("Disconnected \(peripheral.name!). Reconnecting: \(isReconnecting)")
        self.peripheral = nil
        self.currentPosition = nil
        self.delegate?.deskDisconnected(name: peripheral.name!, identifier: peripheral.identifier)
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
                if case .movingUp(let target) = status, currentPosition! >= target - stopFactor {
                    stopMoving()
                } else if case .movingDown(let target) = status, currentPosition! <= target + stopFactor {
                    stopMoving()
                }
            } catch let e {
                print("Error unpacking position: \(e)")
            }
        }
    }
    
    /// Peripheral commands
    
    func moveUp() {
        self.peripheral?.writeValue(DeskServices.valueMoveUp, for: self.characteristicControl, type: .withResponse)
    }
    
    func moveDown() {
        self.peripheral?.writeValue(DeskServices.valueMoveDown, for: self.characteristicControl, type: .withResponse)
    }
    
    func stopMoving() {
        moveTimer?.cancel()
        moveTimer = nil
        status = .idle
        self.peripheral?.writeValue(DeskServices.valueStopMove, for: self.characteristicControl, type: .withResponse)
    }
    
    func wakeUp() {
        self.peripheral?.writeValue(DeskServices.valueWakeUp, for: self.characteristicControl, type: .withResponse)
    }
    
    /**
     Moving to a specific position requires to send command to the desk in a loop.
     The desk controller does not have direct support for moving to a specific position continously.
     */
    func moveToPosition(position: Int) {
        // If we don't have a current position yet, we are trying to move to same position or movement is active then return early
        guard let currentPosition = self.currentPosition, currentPosition != position, moveTimer == nil else {
            return
        }
        
        // Determine direction
        let goingUp = position > currentPosition
        
        // Set status so other methods know what's happening
        if goingUp {
            status = .movingUp(position)
        } else {
            status = .movingDown(position)
        }

        // Create timer to call move commands in intervals for continuous movement
        moveTimer = DispatchSource.makeTimerSource(queue: .main)
        moveTimer!.setEventHandler {
            self.peripheral?.writeValue(goingUp ? DeskServices.valueMoveUp : DeskServices.valueMoveDown, for: self.characteristicControl, type: .withResponse)
        }
        moveTimer!.schedule(deadline: .now(), repeating: .milliseconds(700))
        moveTimer?.resume()
    }
}
