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
    @EnvironmentObject private var clerk: Clerk
    
    private var emailIsEnabled: Bool {
        clerk.environment.userSettings.config(for: .emailAddress)?.enabled == true
    }
    
    private var phoneNumberIsEnabled: Bool {
        clerk.environment.userSettings.config(for: .phoneNumber)?.enabled == true
    }
    
    private var socialProvidersIsEnabled: Bool {
        !clerk.environment.userSettings.enabledThirdPartyProviders.isEmpty
    }
    
    public var body: some View {
        VStack(spacing: 30) {
            HeaderView(title: "Profile Details")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            UserProfileSection()
            
            if emailIsEnabled {
                UserProfileEmailSection()
            }
            
            if phoneNumberIsEnabled {
                UserProfilePhoneNumberSection()
            }
            
            if socialProvidersIsEnabled {
                UserProfileExternalAccountSection()
            }
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
