//
//  UserProfileSecurityView.swift
//
//
//  Created by Mike Pitre on 11/16/23.
//

#if canImport(UIKit)

import SwiftUI

struct UserProfileSecurityView: View {
    @ObservedObject private var clerk = Clerk.shared
    
    private var user: User? {
        clerk.session?.user
    }
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(title: "Security")
                    .multilineTextAlignment(.leading)
                Divider()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if clerk.environment?.userSettings.instanceIsPasswordBased == true {
                UserProfilePasswordSection()
            }
            
            if clerk.environment?.userSettings.secondFactorAttributes.isEmpty == false {
                UserProfileMfaSection()
            }
            
            if !clerk.sessionsByUserId.isEmpty {
                UserProfileActiveDevicesSection()
            }
            
            if clerk.environment?.userSettings.actions.deleteSelf == true && user?.deleteSelfEnabled == true {
                UserProfileDeleteAccountSection()
            }
        }
    }
}

#Preview {
    ScrollView {
        UserProfileSecurityView()
            .padding()
            .padding(.top, 30)
    }
}

#endif
