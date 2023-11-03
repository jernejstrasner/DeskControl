//
//  ContentView.swift
//  DeskControliOS
//
//  Created by Jernej Strasner on 12/10/2023.
//  Copyright © 2023 strsnr. All rights reserved.
//

import SwiftUI
import SentrySwiftUI

struct ContentView: View {
    
    @StateObject var deskConnect = DeskConnect()

    @State private var selectedDesk: Desk?
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
                }.buttonStyle(.borderedProminent)
            }
            .padding()
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
            }
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
