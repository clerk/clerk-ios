//
//  UserProfileDetailsView.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if os(iOS)

import SwiftUI

struct UserProfileDetailsView: View {
    @ObservedObject private var clerk = Clerk.shared
    
    private var emailIsEnabled: Bool {
        clerk.environment?.userSettings.config(for: "email_address")?.enabled == true
    }
    
    private var phoneNumberIsEnabled: Bool {
        clerk.environment?.userSettings.config(for: "phone_number")?.enabled == true
    }
    
    private var socialProvidersIsEnabled: Bool {
        clerk.environment?.userSettings.authenticatableSocialProviders.isEmpty == false
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
}

#endif
