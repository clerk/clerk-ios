//
//  AuthProviderIcon.swift
//
//
//  Created by Mike Pitre on 3/6/24.
//

#if canImport(SwiftUI)

import SwiftUI
import NukeUI

struct AuthProviderIcon: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let provider: ExternalProvider
    
    var iconImageUrl: URL? {
        provider.iconImageUrl(darkMode: colorScheme == .dark)
    }
    
    var body: some View {
        LazyImage(url: iconImageUrl) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}

#Preview {
    AuthProviderIcon(provider: .apple)
}

#endif
