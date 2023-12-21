//
//  UserProfileDetailsView.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

public struct UserProfileDetailsView: View {
    public var body: some View {
        VStack(spacing: 30) {
            HeaderView(title: "Profile Details")
                .frame(maxWidth: .infinity, alignment: .leading)
            UserProfileSection()
            UserProfileEmailSection()
            UserProfilePhoneNumberSection()
            UserProfileExternalAccountSection()
        }
    }
}

#Preview {
    ScrollView {
        UserProfileDetailsView()
            .padding()
            .padding(.vertical)
    }
    .environmentObject(Clerk.mock)
}

#endif
