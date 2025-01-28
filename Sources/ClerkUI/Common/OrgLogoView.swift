//
//  OrgLogoView.swift
//
//
//  Created by Mike Pitre on 12/18/23.
//

#if os(iOS)

import SwiftUI
import Kingfisher

struct OrgLogoView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(ClerkTheme.self) private var clerkTheme
        
    var body: some View {
        KFImage(URL(string: clerk.environment.displayConfig?.logoImageUrl ?? ""))
            .resizable()
            .placeholder {
                #if targetEnvironment(simulator)
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                    Image(systemName: "circle.square.fill")
                        .resizable()
                        .scaledToFit()
                }
                #endif
            }
            .scaledToFit()
    }
}

#Preview {
    OrgLogoView()
        .frame(width: 32, height: 32)
}

#endif
