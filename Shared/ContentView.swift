//
//  ContentView.swift
//  DeskControliOS
//
//  Created by Jernej Strasner on 12/10/2023.
//  Copyright © 2023 strsnr. All rights reserved.
//

import SwiftUI
import SentrySwiftUI
import os.log
#if os(macOS)
import ServiceManagement
#endif

struct ContentView: View {
    
    #if os(iOS)
    @Environment(\.scenePhase) var scenePhase
    #endif

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ContentView")
    @StateObject var deskConnect = DeskConnect()

    @State private var selectedDesk: Desk?
    #if os(macOS)
    // Cached because SMAppService.status is a synchronous XPC call and body
    // re-evaluates on every desk position update, which stalled the main thread.
    @State private var loginItemStatus: SMAppService.Status = SMAppService.mainApp.status
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    #endif
    @AppStorage("sit-position") private var sitPosition: Int?
    @AppStorage("stand-position") private var standPosition: Int?
    
    var body: some View {
        SentryTracedView("Main View") {
            VStack(alignment: .center) {
                HStack {
                    Picker(selection: $selectedDesk) {
                        if let desk = selectedDesk, deskConnect.discoveredDesks.contains(desk) == false {
                            Text(desk.name)
                                .tag(Optional(desk))
                        }
                        ForEach(deskConnect.discoveredDesks.sorted(by: {$0.name < $1.name})) { desk in
                            Text(desk.name)
                                .tag(Optional(desk))
                        }
                    } label: {}
                        .disabled(deskConnect.discoveredDesks.isEmpty)
                    if deskConnect.isScanning {
                        Button {
                            deskConnect.stopDiscovery()
                        } label: {
                            ProgressView()
                                .controlSize(.small)
#if os(iOS)
                                .padding(.trailing, 2)
#endif
                            Text("Cancel")
                        }
                    } else if deskConnect.isConnecting {
                        Button("Cancel") {
                            deskConnect.stopConnecting()
                        }
                    } else {
                        Button("Scan") {
                            deskConnect.startDiscovery()
                        }
                    }
                }
                if selectedDesk != nil, deskConnect.isConnecting {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 4)
                            .controlSize(.small)
                        Text("Connecting...")
                            .foregroundStyle(.secondary)
                    }
                } else if deskConnect.connectedDesk != nil, !deskConnect.isConnecting {
                    Text("Connected")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not connected")
                        .foregroundStyle(.secondary)
                }
                if let error = deskConnect.errorMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                        Spacer()
                        Button {
                            withAnimation {
                                deskConnect.errorMessage = nil
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .imageScale(.small)
                        }
                        .buttonStyle(.borderless)
                    }
                    .font(.callout)
                    .foregroundStyle(.red)
                    .transition(.opacity)
                }
                Divider()
                    .padding(.bottom, 20)
                PressButton(action: { pressed in
                    if pressed {
                        deskConnect.move(.up, continuously: true)
                    } else {
                        deskConnect.stopMoving()
                    }
                }) {
                    Image(systemName: "chevron.up")
                        .imageScale(.large)
                        .foregroundColor(Color.white)
                }
                .disabled(deskConnect.connectedDesk == nil)
#if os(macOS)
                .frame(width: 100, height: 32)
#else
                .frame(width: 100, height: 48)
#endif
                Text(formatPosition(deskConnect.currentPosition))
                    .font(.system(size: 64))
                PressButton(action: { pressed in
                    if pressed {
                        deskConnect.move(.down, continuously: true)
                    } else {
                        deskConnect.stopMoving()
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .imageScale(.large)
                        .foregroundColor(Color.white)
                }
                .disabled(deskConnect.connectedDesk == nil)
#if os(macOS)
                .frame(width: 100, height: 32)
#else
                .frame(width: 100, height: 48)
#endif
                Divider()
                    .padding(.top, 20)
                HStack(alignment: .top) {
                    VStack(alignment: .center) {
                        Text("Sitting position")
                        Text(formatPosition(sitPosition))
                            .font(.system(size: 36))
                        Button {
                            deskConnect.move(to: sitPosition!)
                        } label: {
                            Text("Move to")
                        }
                        .buttonStyle(.bordered)
                        .disabled(sitPosition == nil)
                        Button {
                            sitPosition = deskConnect.currentPosition
                        } label: {
                            Text("Save")
                        }
                        .buttonStyle(.bordered)
                        .disabled(deskConnect.connectedDesk == nil)
                    }.frame(maxWidth: .infinity)
                    Divider()
                    VStack(alignment: .center) {
                        Text("Standing position")
                        Text(formatPosition(standPosition))
                            .font(.system(size: 36))
                        Button {
                            deskConnect.move(to: standPosition!)
                        } label: {
                            Text("Move to")
                        }
                        .buttonStyle(.bordered)
                        .disabled(standPosition == nil)
                        Button {
                            standPosition = deskConnect.currentPosition
                        } label: {
                            Text("Save")
                        }
                        .buttonStyle(.bordered)
                        .disabled(deskConnect.connectedDesk == nil)
                    }.frame(maxWidth: .infinity)
                }.frame(maxWidth: .infinity)
                Button {
                    deskConnect.stopMoving()
                } label: {
                    Text("Stop")
                        .fontWeight(.bold)
                        .padding([.leading, .trailing])
                        .padding([.top, .bottom], 4)
                }
                .buttonStyle(.borderedProminent)
                #if os(macOS)
                Divider()
                Toggle("Launch on login", isOn: $launchAtLogin)
                    .disabled(loginItemStatus == .requiresApproval)
                if loginItemStatus == .requiresApproval {
                    Text("Please go to System Preferences and allow running as a login item")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                    Button {
                        SMAppService.openSystemSettingsLoginItems()
                    } label: {
                        Text("Open System Preferences")
                        Image(systemName: "gear")
                    }
                }
                Button {
                    NSApplication.shared.terminate(self)
                } label: {
                    Image(systemName: "power")
                        .imageScale(.large)
                        .foregroundColor(Color.secondary)
                }
                .buttonStyle(.borderless)
                #endif
            }
            .padding()
            #if os(macOS)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial)
            .ignoresSafeArea()
            #endif
            .animation(.easeInOut(duration: 0.2), value: deskConnect.errorMessage)
            #if os(iOS)
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active, deskConnect.centralState == .poweredOn, deskConnect.isConnecting == false, deskConnect.isScanning == false, deskConnect.connectedDesk == nil {
                    // If we have saved desk try to connect to it straight away
                    if let deskString = UserDefaults.standard.string(forKey: "last-desk"), let desk = Desk(rawValue: deskString) {
                        selectedDesk = desk
                    } else {
                        // Start discovery of new desks
                        deskConnect.startDiscovery()
                    }
                }
            }
            #endif
            .onChange(of: deskConnect.centralState) { value in
                if value == .poweredOn {
                    // If we have saved desk try to connect to it straight away
                    if let deskString = UserDefaults.standard.string(forKey: "last-desk"), let desk = Desk(rawValue: deskString) {
                        selectedDesk = desk
                    } else {
                        // Start discovery of new desks
                        deskConnect.startDiscovery()
                    }
                }
            }
            .onChange(of: selectedDesk) { desk in
                // Stop scanning in case ongoing
                deskConnect.stopDiscovery()
                // Desk was selected so connect to it if not already
                if let desk = desk, desk != deskConnect.connectedDesk {
                    deskConnect.connect(desk: desk)
                }
            }
            .onChange(of: deskConnect.connectedDesk) { desk in
                if let desk = desk {
                    // Desk successfully connected so save it
                    let defaults = UserDefaults.standard
                    defaults.set(desk.rawValue, forKey: "last-desk")
                }
                selectedDesk = desk
            }
            #if os(macOS)
            .onChange(of: launchAtLogin) { value in
                do {
                    if value {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    logger.log(level: .error, "Failed to configure login item")
                }
                loginItemStatus = SMAppService.mainApp.status
            }
            // Pick up approval changes made in System Settings while the menu was closed
            .onAppear {
                loginItemStatus = SMAppService.mainApp.status
            }
            #endif
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
        #if os(macOS)
            .previewLayout(.fixed(width: 360, height: 560))
        #endif
    }
}
