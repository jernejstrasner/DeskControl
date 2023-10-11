//
//  Connect.swift
//  desk
//
//  Created by Forti on 05/06/2020.
//  Copyright © 2020 Forti. All rights reserved.
//

import Foundation
import CoreBluetooth

let deviceNamePattern = #"Desk[\s0-9].*"#

protocol DeskConnectDelegate {
    func deskDiscovered(name: String, identifier: UUID)
    func deskConnected(name: String)
    func deskPositionChanged(position: Int)
}

class DeskConnect: NSObject, CBPeripheralDelegate, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    
    private var characteristicPosition: CBCharacteristic!
    private var characteristicControl: CBCharacteristic!
    private var characteristicMove: CBCharacteristic!
    
    private var moveTimer: DispatchSourceTimer? = nil
    
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
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    func connect(id: UUID) {
        // TODO: Disconnect existing peripheral?
        // TODO: Handle "connecting" state
        if let peripheral = self.discoveredDesks[id] {
            self.peripheral = peripheral
            self.peripheral.delegate = self
            self.centralManager.connect(peripheral)
        } else {
            print("Can't find connected desk with id \(id)")
        }
    }
     
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if (central.state != .poweredOn) {
            print("Central is not powered on. Bluetooth disabled? @TODO")
        } else {
            // TODO: no idea why it doesn't work if I pass in services here
            self.centralManager.scanForPeripherals(withServices: nil)
        }
    }
    
    /**
     ON DISCOVER
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let deviceName = peripheral.name, (self.discoveredDesks[peripheral.identifier] == nil), (deviceName.range(of: deviceNamePattern, options:.regularExpression) != nil) {
            self.discoveredDesks[peripheral.identifier] = peripheral
            self.delegate?.deskDiscovered(name: deviceName, identifier: peripheral.identifier)
        }
    }
    
    /**
     ON CONNECT
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.delegate?.deskConnected(name: peripheral.name!)
        self.peripheral.discoverServices(DeskServices.all)
    }
    
    /**
     ON SERVICES
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                self.peripheral.discoverCharacteristics(DeskServices.characteristicsForService(id: service.uuid), for: service)
            }
        }
    }
    
    /**
     ON CHARACTERISTICS
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                self.peripheral.readValue(for: characteristic)
                self.peripheral.setNotifyValue(true, for: characteristic)
         
                if (characteristic.uuid == DeskServices.controlCharacteristic) {
                    dump(characteristic)
                    self.characteristicControl = characteristic
                }

                if (characteristic.uuid == DeskServices.referenceOutputCharacteristicPosition) {
                    dump(characteristic)
                    self.characteristicPosition = characteristic
                }
                
                if characteristic.uuid == DeskServices.referenceInputCharacteristicMove {
                    dump(characteristic)
                    self.characteristicMove = characteristic
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let value = characteristic.value, characteristic.uuid == DeskServices.referenceOutputCharacteristicPosition {
            do {
                let unpacked = try unpack("<H", value[..<2])
                let position = unpacked[0] as! Int
                currentPosition = DeskServices.baseHeight + position
                
                // If we're moving to target then check if we need to stop here
                if case .movingUp(let target) = status, currentPosition! >= target {
                    stopMoving()
                }
                if case .movingDown(let target) = status, currentPosition! <= target {
                    stopMoving()
                }
            } catch let e {
                print("Error unpacking position: \(e)")
            }
        }
    }
    
    func moveUp() {
        self.peripheral.writeValue(DeskServices.valueMoveUp, for: self.characteristicControl, type: .withResponse)
    }
    
    func moveDown() {
        self.peripheral.writeValue(DeskServices.valueMoveDown, for: self.characteristicControl, type: .withResponse)
    }
    
    func stopMoving() {
        moveTimer?.cancel()
        moveTimer = nil
        status = .idle
        self.peripheral.writeValue(DeskServices.valueStopMove, for: self.characteristicControl, type: .withResponse)
    }
    
    /**
     Moving to a specific position requires to send command to the desk in a loop.
     The desk controller does not have direct support for moving to a specific position continously.
     */
    // TODO: Reduce overshooting
    func moveToPosition(position: Int) {
        // If we don't have a current position yet, we are trying to move to same position or movement is active then return early
        guard let currentPosition = self.currentPosition, currentPosition != position, moveTimer == nil else {
            return
        }
        
        // Determine direction
        let goingUp = position > currentPosition
        
        // Create timer to call move commands in intervals for continuous movement
        moveTimer = DispatchSource.makeTimerSource(queue: .main)
        moveTimer!.setEventHandler {
            self.peripheral.writeValue(goingUp ? DeskServices.valueMoveUp : DeskServices.valueMoveDown, for: self.characteristicControl, type: .withResponse)
        }
        moveTimer!.schedule(deadline: .now(), repeating: .milliseconds(700))
        moveTimer?.resume()
        
        // Set status so other methods know what's happening
        if goingUp {
            status = .movingUp(position)
        } else {
            status = .movingDown(position)
        }
    }
}
