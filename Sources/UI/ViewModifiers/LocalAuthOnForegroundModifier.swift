//
//  LocalAuthPresenting.swift
//
//
//  Created by Mike Pitre on 3/28/24.
//

#if canImport(UIKit)

import SwiftUI

/**
 This modifier injects the clerkUIState into the environment.
 
 You should apply this modifier to the root view of your application. Most likely in your `App` file.
 */
struct LocalAuthOnForegroundModifier: ViewModifier {
    @ObservedObject private var clerk = Clerk.shared
    @State private var isPresented = false
    @State private var shouldTryAuth = true
    @Environment(\.scenePhase) private var scenePhase
    
    func body(content: Content) -> some View {
        content
            .task {
                isPresented = true
            }
            .overlay {
                ZStack {
                    if isPresented && clerk.session != nil {
                        LocalAuthOverlay(onUnlock: {
                            Task {
                                shouldTryAuth = true
                                await authenticate()
                            }
                        }, onSignOut: {
                            Task {
                                await signOut()
                            }
                        })
                    }
                }
                .animation(.default, value: clerk.session == nil)
            }
            .onChange(of: scenePhase) { newValue in
                guard clerk.session != nil else { return }
                switch newValue {
                case .active:
                    if isPresented && clerk.session != nil {
                        Task { await authenticate() }
                    }
                case .inactive, .background:
                    withAnimation {
                        shouldTryAuth = true
                        isPresented = true
                    }
                @unknown default:
                    return
                }
            }
    }
    
    @MainActor
    private func authenticate() async {
        guard shouldTryAuth else { return }
        do {
            try await LocalAuth.authenticateWithFaceID()
            withAnimation {
                isPresented = false
            }
        } catch {
            LocalAuth.context.invalidate()
            shouldTryAuth = false
        }
    }
    
    @MainActor
    private func signOut() async {
        do {
            try await clerk.signOut()
            withAnimation {
                isPresented = false
            }
        } catch {
            clerk.client = Client()
            isPresented = false
            dump(error)
        }
    }
}

fileprivate struct LocalAuthOverlay: View {
    @ObservedObject private var clerk = Clerk.shared
    let onUnlock: () -> Void
    let onSignOut: () -> Void
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                OrgLogoView()
                    .frame(width: 80, height: 80)
                Spacer()
                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                VStack {
                    Button {
                        onUnlock()
                    } label: {
                        Text("Unlock")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkPrimaryButtonStyle())
                    
                    AsyncButton {
                        onSignOut()
                    } label: {
                        Text("Sign Out")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkSecondaryButtonStyle())
                }
                .padding()
            }
        }
    }
}

extension View {
    /**
     This modifier enables local authentication on the app being put into an active state.
     
     You should apply this modifier to the root view of your application. Most likely in your `App` file.
     */
    public func localAuthOnForeground() -> some View {
        modifier(LocalAuthOnForegroundModifier())
    }
}

#Preview {
    LocalAuthOverlay(onUnlock: {}, onSignOut: {})
}

#endif
