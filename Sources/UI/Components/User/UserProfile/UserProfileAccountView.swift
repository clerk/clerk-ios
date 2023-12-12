//
//  UserProfileAccountView.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

public struct UserProfileAccountView: View {
    public var body: some View {
        VStack(spacing: 30) {
            HeaderView(
                title: "Account",
                subtitle: "Manage your account information"
            )
            
            UserProfileSection()
            UserProfileEmailSection()
            UserProfilePhoneNumberSection()
            UserProfileExternalAccountSection()
        }
    }
}

#Preview {
    ScrollView {
        UserProfileAccountView()
            .padding(30)
    }
    .environmentObject(Clerk.mock)
}

#endif
