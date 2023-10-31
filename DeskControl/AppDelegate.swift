//
//  AppDelegate.swift
//  desk
//
//  Created by Forti on 18/05/2020.
//  Copyright © 2020 Forti. All rights reserved.
//

import Cocoa
import SwiftUI

#if DEBUG
@main
struct DeskControlApp: App {
    var body: some Scene {
        MenuBarExtra("Desk Control", image: "MenuIcon") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
#else
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let popover = NSPopover()
    var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let button = statusItem.button {
            button.image = NSImage(named: "MenuIcon")
            button.action = #selector(togglePopover)
        }
        
//        popover.contentViewController = DeskViewController.freshController()
        let viewController = NSHostingController(rootView: ContentView())
        viewController.sizingOptions = [.intrinsicContentSize]
        popover.contentViewController = viewController
//        viewController.view.invalidateIntrinsicContentSize()
    }
    
    @objc
    func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }
    
    func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
        
//        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
//            self?.popover.close()
//        }
    }
    
    func closePopover() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitor = nil
        popover.close()
    }
}
#endif
