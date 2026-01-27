//
//  AppDelegate.swift
//  DeskControl
//
//  Created by strsnr on 1.11.2023.
//  Copyright © 2020 strsnr. All rights reserved.
//

import SwiftUI
import Sentry

@main
struct DeskControlApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = Constants.sentryDSN
            options.tracesSampleRate = 0.1
        }
    }
    
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
