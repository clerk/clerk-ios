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
        ScrollView {
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
            .padding(30)
        }
    }
}

#Preview {
    return UserProfileAccountView()
}

#endif
