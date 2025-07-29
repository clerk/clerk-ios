//
//  OnFirstAppear.swift
//  Clerk
//
//  Created by Mike Pitre on 4/18/25.
//

#if os(iOS)

import Foundation
import SwiftUI

private struct FirstAppear: ViewModifier {
    let action: () -> Void

    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            action()
        }
    }
}

extension View {
    func onFirstAppear(_ action: @escaping () -> ()) -> some View {
        modifier(FirstAppear(action: action))
    }
}

#endif
