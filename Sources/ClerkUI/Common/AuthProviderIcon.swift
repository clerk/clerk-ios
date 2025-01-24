//
//  AuthProviderIcon.swift
//
//
//  Created by Mike Pitre on 3/6/24.
//

#if os(iOS)

import SwiftUI
import Clerk
import Kingfisher

struct AuthProviderIcon: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let provider: OAuthProvider
    
    var iconImageUrl: URL? {
        provider.iconImageUrl(darkMode: colorScheme == .dark)
    }
    
    var body: some View {
        KFImage(iconImageUrl)
            .resizable()
            .scaledToFit()
    }
}

#Preview {
    AuthProviderIcon(provider: .apple)
}

#endif
