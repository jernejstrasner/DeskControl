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
            options.dsn = "https://673adb93f8a210dfc359aac8867c7960@o1146455.ingest.sentry.io/4506157598375936"
            #if DEBUG
            options.debug = true // Enabled debug when first installing is always helpful
            #endif
            
            // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
            // We recommend adjusting this value in production.
            options.tracesSampleRate = 1.0
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
