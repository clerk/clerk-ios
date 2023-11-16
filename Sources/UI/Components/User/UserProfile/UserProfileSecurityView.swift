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
        ScrollView {
            VStack(spacing: 30) {
                HeaderView(
                    title: "Security",
                    subtitle: "Manage your security preferences"
                )
                
                UserProfileActiveDevicesSection()
            }
            .padding(30)
        }
    }
}

#Preview {
    UserProfileSecurityView()
        .environmentObject(Clerk.mock)
}

#endif
