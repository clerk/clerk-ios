//
//  OrgLogoView.swift
//
//
//  Created by Mike Pitre on 12/18/23.
//

#if os(iOS)

import SwiftUI
import NukeUI

struct OrgLogoView: View {
    var clerk = Clerk.shared
    @Environment(\.clerkTheme) private var clerkTheme
        
    var body: some View {
        LazyImage(request: .init(url: URL(string: clerk.environment?.displayConfig.logoImageUrl ?? ""))) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFit()
            }
            
            #if targetEnvironment(simulator)
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                Image(systemName: "circle.square.fill")
                    .resizable()
                    .scaledToFit()
            }
            #endif
        }
    }
}

#Preview {
    OrgLogoView()
        .frame(width: 32, height: 32)
}

#endif
