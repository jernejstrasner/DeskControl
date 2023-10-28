//
//  DeskObserver.swift
//  DeskControliOS
//
//  Created by Jernej Strasner on 27. 10. 23.
//  Copyright © 2023 Forti. All rights reserved.
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
    @Published var currentPosition: Int? = nil
    @Published var connectedDesk: Desk? = nil
    @Published var discoveredDesks: Set<Desk> = []
    
    private var deskConnect: DeskConnect!
    
    init() {
        deskConnect = DeskConnect()
        deskConnect.delegate = self
    }
    
    func deskDiscovered(name: String, identifier: UUID) {
        discoveredDesks.insert(Desk(id: identifier, name: name))
    }
    
    func deskConnected(name: String, identifier: UUID) {
        connectedDesk = Desk(id: identifier, name: name)
    }
    
    func deskDisconnected(name: String, identifier: UUID) {
        connectedDesk = nil
    }
    
    func deskPositionChanged(position: Int) {
        currentPosition = position
    }
    
    // Public API
    
    func connect(id: UUID) {
        deskConnect.connect(id: id)
    }
    
    func moveUp() {
        deskConnect.moveUp()
    }
    
    func moveDown() {
        deskConnect.moveDown()
    }
    
    func stopMoving() {
        deskConnect.stopMoving()
    }
    
    func moveTo(position: Int) {
        deskConnect.moveToPosition(position: position)
    }
    
    func wakeUp() {
        deskConnect.wakeUp()
    }

}
