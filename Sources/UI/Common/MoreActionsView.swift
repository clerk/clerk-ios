//
//  MoreActionsView.swift
//
//
//  Created by Mike Pitre on 1/11/24.
//

#if canImport(SwiftUI)

import SwiftUI

struct MoreActionsView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    var body: some View {
        Image(systemName: "ellipsis")
            .fontWeight(.ultraLight)
            .frame(minWidth: 20, minHeight: 20)
            .padding(4)
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 4))
    }
}

#Preview {
    MoreActionsView()
}

#endif
