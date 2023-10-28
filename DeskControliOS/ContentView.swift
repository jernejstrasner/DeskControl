//
//  ContentView.swift
//  DeskControliOS
//
//  Created by Jernej Strasner on 12/10/2023.
//  Copyright © 2023 Forti. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject var deskObserver = DeskObserver()
    
    @State private var isSelectingDesk = false

    @AppStorage("last-desk") private var selectedDesk: Desk?
    @AppStorage("sit-position") private var sitPosition: Int?
    @AppStorage("stand-position") private var standPosition: Int?
    
    var body: some View {
        VStack(alignment: .center) {
            Button(selectedDesk == nil ? "Select Desk" : "\(selectedDesk!.name)") {
                isSelectingDesk = true
            }
            .font(.system(size: 24))
            .padding([.top, .leading, .trailing])
            .fullScreenCover(isPresented: $isSelectingDesk) {
                NavigationStack {
                    List {
                        ForEach(Array(deskObserver.discoveredDesks), id: \.id) { desk in
                            HStack {
                                Button(desk.name) {
                                    selectedDesk = desk
                                    deskObserver.connect(id: desk.id)
                                    isSelectingDesk = false
                                }
                                if selectedDesk == desk {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    .navigationTitle("Select Desk")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isSelectingDesk = false
                            }
                        }
                    }
                }
            }
            if let desk = deskObserver.connectedDesk, desk == selectedDesk {
                Text("Connected").padding(.bottom)
            } else {
                Text("Not connected").padding(.bottom)
            }
            Divider()
            Button {
                deskObserver.moveUp()
            } label: {
                Image(systemName: "chevron.up")
                    .imageScale(.large)
                    .padding([.leading, .trailing])
                    .padding([.top, .bottom], 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(deskObserver.connectedDesk == nil)
            Text(formatPosition(deskObserver.currentPosition))
                .font(.system(size: 64))
            Button {
                deskObserver.moveDown()
            } label: {
                Image(systemName: "chevron.down")
                    .imageScale(.large)
                    .padding([.leading, .trailing])
                    .padding([.top, .bottom], 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(deskObserver.connectedDesk == nil)
            Divider()
            HStack(alignment: .top) {
                VStack(alignment: .center) {
                    Text("Sitting position")
                    Text(formatPosition(sitPosition))
                        .font(.system(size: 36))
                    Button {
                        deskObserver.moveTo(position: sitPosition!)
                    } label: {
                        Text("Move to")
                    }
                    .buttonStyle(.bordered)
                    .disabled(sitPosition == nil)
                    Button {
                        sitPosition = deskObserver.currentPosition
                    } label: {
                        Text("Save")
                    }
                    .buttonStyle(.bordered)
                    .disabled(deskObserver.connectedDesk == nil)
                }.frame(maxWidth: .infinity)
                Divider()
                VStack(alignment: .center) {
                    Text("Standing position")
                    Text(formatPosition(standPosition))
                        .font(.system(size: 36))
                    Button {
                        deskObserver.moveTo(position: standPosition!)
                    } label: {
                        Text("Move to")
                    }
                    .buttonStyle(.bordered)
                    .disabled(standPosition == nil)
                    Button {
                        standPosition = deskObserver.currentPosition
                    } label: {
                        Text("Save")
                    }
                    .buttonStyle(.bordered)
                    .disabled(deskObserver.connectedDesk == nil)
                }.frame(maxWidth: .infinity)
            }.frame(maxWidth: .infinity)
            Button {
                deskObserver.stopMoving()
            } label: {
                Text("Stop")
                    .fontWeight(.bold)
                    .padding([.leading, .trailing])
                    .padding([.top, .bottom], 4)
            }.buttonStyle(.borderedProminent)
        }
        .padding()
        .onChange(of: deskObserver.discoveredDesks) { _ in
            // If we have saved desk try to connect to it straight away
            if let desk = selectedDesk {
                deskObserver.connect(id: desk.id)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
