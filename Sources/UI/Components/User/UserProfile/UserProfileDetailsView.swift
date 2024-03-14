//
//  UserProfileDetailsView.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI

struct UserProfileDetailsView: View {
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
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(title: "Profile Details")
                    .multilineTextAlignment(.leading)
                Divider()
            }
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
            .padding(.top, 30)
    }
    .environmentObject(Clerk.shared)
}

#endif
