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
    func deskPositionChanged(position: Double)
}

class DeskConnect: NSObject, CBPeripheralDelegate, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    
    private var characteristicPosition: CBCharacteristic!
    private var characteristicControl: CBCharacteristic!
    
    private var valueMoveUp = pack("<H", [71, 0])
    private var valueMoveDown = pack("<H", [70, 0])
    private var valueStopMove = pack("<H", [255, 0])
    
    private var moveToPositionValue: Double? = nil
    private var moveToPositionTimer: Timer?
    
    private var discoveredDesks: [UUID: CBPeripheral] = [:]
    
    var delegate: DeskConnectDelegate?
    
    var currentPosition: Double? = nil {
        didSet {
            if let val = currentPosition {
                self.delegate?.deskPositionChanged(position: val)
            }
        }
    }
    
    let deskOffset = 62.5
    
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
            print("Discovered \(deviceName) <\(peripheral.identifier)>")
            self.discoveredDesks[peripheral.identifier] = peripheral
            self.delegate?.deskDiscovered(name: deviceName, identifier: peripheral.identifier)
            dump(self.discoveredDesks)
        }
    }
    
    /**
     ON CONNECT
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected \(peripheral.name ?? "<unnamed>") <\(peripheral.identifier)>")
        self.delegate?.deskConnected(name: peripheral.name!)
        self.peripheral.discoverServices(DeskServices.all)
    }
    
    /**
     ON SERVICES
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("Discovered services \(peripheral.name ?? "<unnamed>") <\(peripheral.identifier)>")
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
                    self.characteristicControl = characteristic
                }

                if (characteristic.uuid == DeskServices.referenceOutputCharacteristicPosition) {
                    self.characteristicPosition = characteristic
                    self.updatePosition(characteristic: characteristic)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        self.updatePosition(characteristic: characteristic)
    }
    
    func moveUp() {
        print("up")
        self.peripheral.writeValue(Data(self.valueMoveUp), for: self.characteristicControl, type: CBCharacteristicWriteType.withResponse)
    }
    
    func moveDown() {
        print("down")
        self.peripheral.writeValue(Data(self.valueMoveDown), for: self.characteristicControl, type: CBCharacteristicWriteType.withResponse)
    }
    
    private func updatePosition(characteristic: CBCharacteristic) {
        if (characteristic.value != nil && characteristic.uuid.uuidString == self.characteristicPosition.uuid.uuidString) {
            let byteArray = [UInt8](characteristic.value!)
            if (byteArray.indices.contains(0) && byteArray.indices.contains(1)) {
                do {
                    let positionWrapped = try unpack("<H", Data([byteArray[0], byteArray[1]]))
                    if let position = positionWrapped[0] as? Int {
                        
                        let formattedPosition = (round(Double(position) + (self.deskOffset * 100)) / 100)
                        let roundedPosition = round(formattedPosition / 0.5) * 0.5
                        self.currentPosition = roundedPosition

                        if let requiredPosition = self.moveToPositionValue {
                            if (formattedPosition > (requiredPosition - 0.75) && formattedPosition < (requiredPosition + 0.75)) {
                                self.moveToPositionTimer?.invalidate()
                                self.moveToPositionValue = nil
                                self.stopMoving()
                            }
                        }
                    }
                } catch let error as NSError {
                    print("Error, update position: \(error)")
                }
            }
        }
    }
    
    @objc func stopMoving() {
//        self.peripheral.writeValue(Data(self.valueStopMove), for: self.characteristicControl, type: CBCharacteristicWriteType.withResponse)
        moveToPositionTimer?.invalidate()
        moveToPositionTimer = nil
    }

    func moveToPosition(position: Double) {
        self.moveToPositionValue = position
        self.handleMoveToPosition()
        
        self.moveToPositionTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { (Timer) in
            if (self.moveToPositionValue == nil) {
                Timer.invalidate()
            } else {
                self.handleMoveToPosition()
            }
        }
    }

    public func isMoving() -> Bool {
        return self.moveToPositionTimer?.isValid ?? false
    }

    private func handleMoveToPosition() {
        if let positionRequired = self.moveToPositionValue, let currentPosition = self.currentPosition {
            if positionRequired < currentPosition {
                self.moveDown()
            } else if (positionRequired > currentPosition) {
                self.moveUp()
            }
        }
    }
}
