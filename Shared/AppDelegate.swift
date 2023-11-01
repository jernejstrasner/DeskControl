//
//  AppDelegate.swift
//  DeskControl
//
//  Created by strsnr on 1.11.2023.
//  Copyright © 2020 strsnr. All rights reserved.
//

import SwiftUI

@main
struct DeskControlApp: App {
    var body: some Scene {
        #if os(macOS)
        MenuBarExtra("Desk Control", image: "MenuIcon") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
        #else
        WindowGroup {
            ContentView()
        }
        #endif
    }
}
