//
//  ContentView.swift
//  DeskControliOS
//
//  Created by Jernej Strasner on 12/10/2023.
//  Copyright © 2023 Forti. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .center) {
            Text("<desk selection>")
            Text("<desk status>")
            Button {
                // TODO
            } label: {
                Image(systemName: "chevron.up")
                    .imageScale(.large)
            }.buttonStyle(.borderedProminent)
            Text("99.9")
                .font(.system(size: 64))
            Button {
                
            } label: {
                Image(systemName: "chevron.down")
                    .imageScale(.large)
            }.buttonStyle(.borderedProminent)
            Divider()
            HStack(alignment: .top) {
                VStack(alignment: .center) {
                    Text("Sitting position")
                    Text("99.9")
                        .font(.system(size: 36))
                    Button {
                        
                    } label: {
                        Text("Move to")
                    }
                    .buttonStyle(.bordered)
                    Button {
                        
                    } label: {
                        Text("Save")
                    }
                    .buttonStyle(.bordered)
                }.frame(maxWidth: .infinity)
                Divider()
                VStack(alignment: .center) {
                    Text("Standing position")
                    Text("99.9")
                        .font(.system(size: 36))
                    Button {
                        
                    } label: {
                        Text("Move to")
                    }
                    .buttonStyle(.bordered)
                    Button {
                        
                    } label: {
                        Text("Save")
                    }
                    .buttonStyle(.bordered)
                }.frame(maxWidth: .infinity)
            }.frame(maxWidth: .infinity)
            Button {
                
            } label: {
                Text("Stop").fontWeight(.bold)
            }.buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
