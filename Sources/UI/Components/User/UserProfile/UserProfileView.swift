//
//  UserProfileView.swift
//  
//
//  Created by Mike Pitre on 11/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

public struct UserProfileView: View {
    @EnvironmentObject private var clerk: Clerk
    @State private var errorWrapper: ErrorWrapper?
    
    private var removeDismissButton: Bool = false
    
    public init() {}
    
    private var user: User? {
        clerk.user
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                UserProfileDetailsView()
                UserProfileSecurityView()
            }
            .padding()
            .padding(.top, removeDismissButton ? 0 : nil)
            .animation(.snappy, value: user)
        }
        .clerkErrorPresenting($errorWrapper)
        .dismissButtonOverlay(hidden: removeDismissButton)
        .task {
            do {
                try await clerk.client.get()
            } catch {
                errorWrapper = ErrorWrapper(error: error)
                dump(error)
            }
        }
        .task {
            do {
                try await clerk.client.lastActiveSession?.user?.getSessions()
            } catch {
                errorWrapper = ErrorWrapper(error: error)
                dump(error)
            }
        }
    }
}

extension UserProfileView {
    
    public func removeDismissButton(_ remove: Bool = true) -> Self {
        var copy = self
        copy.removeDismissButton = remove
        return copy
    }
    
}

#Preview {
    UserProfileView()
        .environmentObject(Clerk.mock)
}

#endif
