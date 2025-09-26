//
//  AppLogoView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/16/25.
//

#if os(iOS)

import ClerkKit
import NukeUI
import SwiftUI

struct AppLogoView: View {
    @Environment(\.clerk) private var clerk

    var body: some View {
        LazyImage(url: URL(string: clerk.environment.displayConfig?.logoImageUrl ?? "")) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}

#Preview {
    AppLogoView()
        .padding()
}

#endif
