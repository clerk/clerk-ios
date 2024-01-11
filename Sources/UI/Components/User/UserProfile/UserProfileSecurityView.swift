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
    @EnvironmentObject private var clerk: Clerk
    
    public var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(title: "Security")
                    .multilineTextAlignment(.leading)
                Divider()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if clerk.environment.userSettings.instanceIsPasswordBased {
                UserProfilePasswordSection()
            }
            
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
