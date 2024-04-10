//
//  OrgLogoView.swift
//
//
//  Created by Mike Pitre on 12/18/23.
//

#if canImport(UIKit)

import SwiftUI
import NukeUI

public struct OrgLogoView: View {
    @ObservedObject private var clerk = Clerk.shared
    @Environment(\.clerkTheme) private var clerkTheme
    
    public init() {}
    
    public var body: some View {
        LazyImage(request: .init(url: URL(string: clerk.environment?.displayConfig.logoImageUrl ?? ""))) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}

#Preview {
    OrgLogoView()
        .frame(width: 32, height: 32)
}

#endif
