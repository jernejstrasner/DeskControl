//
//  DeskObserver.swift
//  DeskControliOS
//
//  Created by Jernej Strasner on 27. 10. 23.
//  Copyright © 2023 strsnr. All rights reserved.
//

import Foundation

struct Desk: Identifiable, Hashable {
    let id: UUID
    let name: String
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

class DeskObserver: ObservableObject, DeskConnectDelegate {
    @Published var connectReady: Bool = false
    @Published var currentPosition: Int? = nil
    @Published var connectedDesk: Desk? = nil
    @Published var discoveredDesks: Set<Desk> = []
    @Published var isScanning: Bool = false
    @Published var isConnecting: Bool = false
    
    private var deskConnect: DeskConnect!
    
    init() {
        deskConnect = DeskConnect()
        deskConnect.delegate = self
    }
    
    func deskConnectReady() {
        connectReady = true
    }
    
    func deskDiscovered(name: String, identifier: UUID) {
        discoveredDesks.insert(Desk(id: identifier, name: name))
    }
    
    func deskConnected(name: String, identifier: UUID) {
        isConnecting = false
        connectedDesk = Desk(id: identifier, name: name)
    }
    
    func deskFailedToConnect(name: String, identifier: UUID) {
        isConnecting = false
        connectedDesk = nil
    }
    
    func deskDisconnected(name: String, identifier: UUID) {
        connectedDesk = nil
    }
    
    func deskPositionChanged(position: Int) {
        currentPosition = position
    }
    
    // Public API
    
    func startDiscovery(timeout: DispatchTimeInterval = .seconds(15)) {
        isScanning = true
        deskConnect.startDiscovery()
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.stopDiscovery()
        }
    }
    
    func stopDiscovery() {
        deskConnect.stopDiscovery()
        isScanning = false
    }
    
    func connect(desk: Desk) {
        isConnecting = true
        deskConnect.connect(desk: desk)
    }
    
    func moveUp() {
        deskConnect.moveUp()
    }
    
    func moveDown() {
        deskConnect.moveDown()
    }
    
    private var moveTimer: DispatchSourceTimer? = nil
    
    func moveUpContinuously() {
        stopMoving()
        let timer = DispatchSource.makeTimerSource()
        timer.setEventHandler { [weak self] in
            self?.deskConnect.moveUp()
        }
        timer.schedule(deadline: .now(), repeating: .milliseconds(700))
        timer.resume()
        moveTimer = timer
    }
    
    func moveDownContinuously() {
        stopMoving()
        let timer = DispatchSource.makeTimerSource()
        timer.setEventHandler { [weak self] in
            self?.deskConnect.moveDown()
        }
        timer.schedule(deadline: .now(), repeating: .milliseconds(700))
        timer.resume()
        moveTimer = timer
    }
    
    func stopMoving() {
        moveTimer?.cancel()
        moveTimer = nil
        deskConnect.stopMoving()
    }
    
    func moveTo(position: Int) {
        deskConnect.moveToPosition(position: position)
    }
    
    func wakeUp() {
        deskConnect.wakeUp()
    }

}
