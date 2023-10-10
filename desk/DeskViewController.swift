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
    private var longClick: NSPressGestureRecognizer?
    private var userDefaults: UserDefaults?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        deskConnect = DeskConnect()
        deskConnect.delegate = self
        
        buttonUp.isEnabled = false
        buttonDown.isEnabled = false
        
        userDefaults = UserDefaults.init(suiteName: "positions")
        let sitPosition = userDefaults!.double(forKey: "sit-position")
        if sitPosition > 0 {
            self.sitPosition.stringValue = String(format:"%.1f", sitPosition)
        }
        let standPosition = userDefaults!.double(forKey: "stand-position")
        if standPosition > 0 {
            self.standPosition.stringValue = String(format:"%.1f", standPosition)
        }

        buttonUp.sendAction(on: .leftMouseDown)
        buttonUp.isContinuous = true
        buttonUp.setPeriodicDelay(0, interval: 0.7)
        
        buttonDown.sendAction(on: .leftMouseDown)
        buttonDown.isContinuous = true
        buttonDown.setPeriodicDelay(0, interval: 0.7)
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
    
    var currentPosition: Double! {
        didSet {
            self.currentValue.stringValue = String(format:"%.1f", currentPosition)
        }
    }
    
    var isWaitingForSecondPress = false
    @objc func stopMoving() {
        self.deskConnect.stopMoving()
        self.isWaitingForSecondPress = true
    }
    
    @objc func clearIsWairingForSecondPress() {
        self.isWaitingForSecondPress = false
    }
    
    func handleStopMovingIfSingleClick() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(clearIsWairingForSecondPress), object: nil)
        
        if (self.isWaitingForSecondPress == false) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: { [weak self] in
                self?.deskConnect.stopMoving()
            })
//            perform(#selector(stopMoving), with: nil, afterDelay: 0.18)
        }
        
        perform(#selector(clearIsWairingForSecondPress), with: nil, afterDelay: 0.2)
    }
    
    @IBAction func selectedDesk(_ sender: NSPopUpButton) {
        if let obj = sender.selectedItem?.representedObject as? UUID {
            deskConnect.connect(id: obj)
        }
    }
    
    @IBAction func up(_ sender: NSButton) {
        self.deskConnect.moveUp()
        self.handleStopMovingIfSingleClick()
    }
    
    @IBAction func down(_ sender: NSButton) {
        self.deskConnect.moveDown()
        self.handleStopMovingIfSingleClick()
    }
    
    @IBAction func saveAsSitPosition(_ sender: NSButton) {
        self.userDefaults!.set(self.currentPosition, forKey: "sit-position")
        self.sitPosition.stringValue = String(format:"%.1f", self.currentPosition)
    }
    
    @IBAction func saveAsStandPosition(_ sender: NSButton) {
        self.userDefaults!.set(self.currentPosition, forKey: "stand-position")
        self.standPosition.stringValue = String(format:"%.1f", self.currentPosition)
    }
    
    @IBAction func moveToSitPosition(_ sender: NSButton) {
        if let position = self.userDefaults?.double(forKey: "sit-position") {
            self.deskConnect.moveToPosition(position: position)
        }
    }
    
    @IBAction func moveToStandPosition(_ sender: NSButton) {
        if let position = self.userDefaults?.double(forKey: "stand-position") {
            self.deskConnect.moveToPosition(position: position)
        }
    }

    @IBAction func stopMoving(_ sender: NSButton) {
        deskConnect.stopMoving()
    }

    // MARK: DeskConnectDelegate
    
    func deskDiscovered(name: String, identifier: UUID) {
        let item = NSMenuItem()
        item.title = name
        item.representedObject = identifier
        deviceChoices.menu?.addItem(item)
    }
    
    func deskConnected(name: String) {
        self.buttonUp.isEnabled = true
        self.buttonDown.isEnabled = true
        // TODO: Save last connected desk
    }
    
    func deskPositionChanged(position: Double) {
        self.currentPosition = position
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

