//
//  EraseToAnyView.swift
//
//
//  Created by Mike Pitre on 9/13/24.
//

#if os(iOS)

import SwiftUI

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

#endif
