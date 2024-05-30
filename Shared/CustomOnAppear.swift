//
//  CustomOnAppear.swift
//  DeskControl
//
//  Created by Jernej Strasner on 30. 5. 24.
//

import SwiftUI
import Cocoa

private typealias VoidBlock = () -> Void

struct ViewControllerRepresentable: NSViewControllerRepresentable {
    fileprivate let onAppear: VoidBlock?
    fileprivate let onDisappear: VoidBlock?

    func makeNSViewController(context: Context) -> NSViewController {
        ViewController(onAppear: onAppear, onDisappear: onDisappear)
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}

    class ViewController: NSViewController {
        
        fileprivate let onAppear: VoidBlock?
        fileprivate let onDisappear: VoidBlock?

        fileprivate init(onAppear: VoidBlock? = nil, onDisappear: VoidBlock? = nil) {
            self.onAppear = onAppear
            self.onDisappear = onDisappear
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func viewDidAppear() {
            super.viewDidAppear()
            onAppear?()
        }

        override func viewDidDisappear() {
            super.viewDidDisappear()
            onDisappear?()
        }
    }
}

struct AppearanceModifier: ViewModifier {
    fileprivate let appearAction: VoidBlock
    fileprivate let disappearAction: VoidBlock

    func body(content: Content) -> some View {
        content
            .background(ViewControllerRepresentable(onAppear: appearAction, onDisappear: disappearAction))
    }
}

extension View {
    func onAppearanceEvent(onAppear: @escaping () -> Void, onDisappear: @escaping () -> Void) -> some View {
        self.modifier(AppearanceModifier(appearAction: onAppear, disappearAction: onDisappear))
    }
}
