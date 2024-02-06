//
//  UserProfileView.swift
//  
//
//  Created by Mike Pitre on 11/16/23.
//

#if canImport(UIKit)

import SwiftUI
import ClerkSDK

public struct UserProfileView: View {
    @EnvironmentObject private var clerk: Clerk
    @State private var errorWrapper: ErrorWrapper?
        
    public init() {}
    
    private var user: User? {
        clerk.user
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 30) {
                UserProfileDetailsView()
                UserProfileSecurityView()
            }
            .padding()
        }
        .clerkBottomBranding()
        .animation(.snappy, value: user)
        .clerkErrorPresenting($errorWrapper)
        .task {
            do {
                try await clerk.client.get()
            } catch {
                errorWrapper = ErrorWrapper(error: error)
                dump(error)
            }
        }
        .task(id: user?.id) {
            do {
                try await clerk.client.lastActiveSession?.user?.getSessions()
            } catch {
                errorWrapper = ErrorWrapper(error: error)
                dump(error)
            }
        }
        .task {
            try? await clerk.environment.get()
        }
    }
}

#Preview {
    UserProfileView()
        .environmentObject(Clerk.mock)
}

#endif
