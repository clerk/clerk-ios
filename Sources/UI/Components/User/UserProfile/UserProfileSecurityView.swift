//
//  UserProfileSecurityView.swift
//
//
//  Created by Mike Pitre on 11/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct UserProfileSecurityView: View {
    public var body: some View {
        VStack(spacing: 30) {
            HeaderView(title: "Security")
                .frame(maxWidth: .infinity, alignment: .leading)
            UserProfilePasswordSection()
            UserProfileActiveDevicesSection()
        }
    }
}

#Preview {
    ScrollView {
        UserProfileSecurityView()
            .padding()
            .padding(.vertical)
    }
    .environmentObject(Clerk.mock)
}

#endif
