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
        VStack(spacing: 30) {
            HeaderView(title: "Security")
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
