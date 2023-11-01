//
//  PressButton.swift
//  DeskControl
//
//  Created by Jernej Strasner on 1. 11. 23.
//

import SwiftUI

public struct PressButton<Label>: View where Label: View {

    @Environment(\.isEnabled) var isEnabled

    let action: (Bool) -> Void
    let label: Label

    public init(action: @escaping (Bool) -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(!isEnabled ? Color.secondary : Color.accentColor)
            .onLongPressGesture(minimumDuration: .infinity, perform: {}) { pressing in
                action(pressing)
            }
            .disabled(!isEnabled)
            .overlay {
                label
                    .allowsHitTesting(false)
            }
    }

}
