//
//  DeskViewcontroller.swift
//  desk
//
//  Created by Forti on 18/05/2020.
//  Copyright © 2020 Forti. All rights reserved.
//

import Cocoa

class DeskViewController: NSViewController, DeskConnectDelegate {
    private var deskConnect: DeskConnect!
    private var userDefaults: UserDefaults?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        deskConnect = DeskConnect()
        deskConnect.delegate = self
        
        buttonUp.isEnabled = false
        buttonDown.isEnabled = false
        
        userDefaults = UserDefaults.init(suiteName: "positions")
        sitPositionValue = userDefaults!.integer(forKey: "sit-position")
        standPositionValue = userDefaults!.integer(forKey: "stand-position")

        buttonUp.sendAction(on: [.leftMouseDown, .leftMouseUp])
        buttonUp.isContinuous = true
        buttonUp.setPeriodicDelay(0, interval: 0.7)
        
        buttonDown.sendAction(on: [.leftMouseDown, .leftMouseUp])
        buttonDown.isContinuous = true
        buttonDown.setPeriodicDelay(0, interval: 0.7)
        
        // Get the last connected desk and create a disable menu item
        if let lastDesk = userDefaults!.string(forKey: "desk-id"), let identifier = UUID(uuidString: lastDesk), let deskName = userDefaults!.string(forKey: "desk-name") {
            let item = NSMenuItem()
            item.tag = identifier.hashValue
            item.title = deskName
            item.representedObject = identifier
            item.isEnabled = false
            deviceChoices.menu?.addItem(item)
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        deskConnect.wakeUp()
    }
    
    @IBOutlet var deskStatus: NSTextField!
    @IBOutlet var deviceChoices: NSPopUpButton!
    @IBOutlet var currentValue: NSTextField!
    @IBOutlet var buttonUp: NSButton!
    @IBOutlet var buttonDown: NSButton!
    @IBOutlet var buttonMoveToSit: NSButton!
    @IBOutlet var buttonMoveToStand: NSButton!
    @IBOutlet var sitPosition: NSTextField!
    @IBOutlet var standPosition: NSTextField!
    
    var currentPosition: Int! {
        didSet {
            self.currentValue.stringValue = formatPosition(currentPosition)
        }
    }
    
    var sitPositionValue: Int? {
        didSet {
            self.sitPosition.stringValue = formatPosition(sitPositionValue)
        }
    }
    
    var standPositionValue: Int? {
        didSet {
            self.standPosition.stringValue = formatPosition(standPositionValue)
        }
    }
    
    @IBAction func selectedDesk(_ sender: NSPopUpButton) {
        if let obj = sender.selectedItem?.representedObject as? UUID {
            deskStatus.stringValue = "Connecting..."
            deskConnect.connect(id: obj)
            userDefaults!.set(obj.uuidString, forKey: "desk-id")
            userDefaults!.set(sender.selectedItem?.title, forKey: "desk-name")
        }
    }
    
    @IBAction func up(_ sender: NSButton) {
        if let event = NSApp.currentEvent {
            if event.type == .leftMouseDown || event.type == .periodic {
                deskConnect.moveUp()
            } else if event.type == .leftMouseUp {
                deskConnect.stopMoving()
            }
        }
    }
    
    @IBAction func down(_ sender: NSButton) {
        if let event = NSApp.currentEvent {
            if event.type == .leftMouseDown || event.type == .periodic {
                deskConnect.moveDown()
            } else if event.type == .leftMouseUp {
                deskConnect.stopMoving()
            }
        }
    }
    
    @IBAction func saveAsSitPosition(_ sender: NSButton) {
        self.userDefaults!.set(self.currentPosition, forKey: "sit-position")
        self.sitPositionValue = self.currentPosition
    }
    
    @IBAction func saveAsStandPosition(_ sender: NSButton) {
        self.userDefaults!.set(self.currentPosition, forKey: "stand-position")
        self.standPositionValue = self.currentPosition
    }
    
    @IBAction func moveToSitPosition(_ sender: NSButton) {
        if let position = self.userDefaults?.integer(forKey: "sit-position") {
            self.deskConnect.moveToPosition(position: position)
        }
    }
    
    @IBAction func moveToStandPosition(_ sender: NSButton) {
        if let position = self.userDefaults?.integer(forKey: "stand-position") {
            self.deskConnect.moveToPosition(position: position)
        }
    }

    @IBAction func stopMoving(_ sender: NSButton) {
        deskConnect.stopMoving()
    }

    // MARK: DeskConnectDelegate
    
    func deskDiscovered(name: String, identifier: UUID) {
        // Check if desk is already there from being saved and update
        if let item = deviceChoices.menu!.item(withTag: identifier.hashValue) {
            item.title = name
            item.representedObject = identifier
            item.isEnabled = true
        } else {
            let item = NSMenuItem()
            item.tag = identifier.hashValue
            item.title = name
            item.representedObject = identifier
            deviceChoices.menu!.addItem(item)
        }
        // If there's only one desk total then connect to it
        if deviceChoices.menu!.items.count == 1, let item = deviceChoices.menu!.items.first {
            deviceChoices.select(item)
            deskStatus.stringValue = "Connecting..."
            deskConnect.connect(id: identifier)
        }
    }
    
    func deskConnected(name: String, identifier: UUID) {
        buttonUp.isEnabled = true
        buttonDown.isEnabled = true
        deskStatus.stringValue = "Connected"
    }
    
    func deskDisconnected(name: String, identifier: UUID) {
        buttonUp.isEnabled = false
        buttonUp.isEnabled = false
        if deviceChoices.selectedItem?.tag == identifier.hashValue {
            deskStatus.stringValue = "Disconnected"
        }
    }
    
    func deskPositionChanged(position: Int) {
        currentPosition = position
    }
}

extension DeskViewController {
    // MARK: Storyboard instantiation
    static func freshController() -> DeskViewController {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let viewcontroller = storyboard.instantiateController(withIdentifier: "DeskViewController") as? DeskViewController else {
            fatalError("Can't find DeskViewController - Check Main.storyboard")
        }
        return viewcontroller
    }
}

