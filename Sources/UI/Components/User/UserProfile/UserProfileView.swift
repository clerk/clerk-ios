//
//  UserProfileView.swift
//  
//
//  Created by Mike Pitre on 11/16/23.
//

#if canImport(UIKit)

import SwiftUI

public struct UserProfileView: View {
    @ObservedObject private var clerk = Clerk.shared
    @State private var errorWrapper: ErrorWrapper?
    @Environment(\.dismiss) private var dismiss
        
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
            .padding(.bottom)
        }
        .overlay {
            if clerk.session == nil {
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    ProgressView()
                }
            }
        }
        .clerkBottomBranding()
        .clerkErrorPresenting($errorWrapper)
        .task {
            do {
                try await clerk.client?.get()
            } catch {
                errorWrapper = ErrorWrapper(error: error)
                dump(error)
            }
        }
        .task(id: user?.id) {
            do {
                try await clerk.client?.lastActiveSession?.user?.getSessions()
            } catch {
                errorWrapper = ErrorWrapper(error: error)
                dump(error)
            }
        }
        .task {
            try? await clerk.getEnvironment()
        }
        .onChange(of: clerk.session) { lastActiveSession in
            if lastActiveSession == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    UserProfileView()
}

#endif
