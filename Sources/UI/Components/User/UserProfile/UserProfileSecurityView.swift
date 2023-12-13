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
            UserProfilePasswordSection()
            UserProfileActiveDevicesSection()
        }
    }
}

#Preview {
    ScrollView {
        UserProfileSecurityView()
            .padding(30)
    }
    .environmentObject(Clerk.mock)
}

#endif
