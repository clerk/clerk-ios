//
//  UserButtonPopover.swift
//
//
//  Created by Mike Pitre on 11/29/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct UserButtonPopover: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.dismiss) private var dismiss
    @State private var errorWrapper: ErrorWrapper?
    @Namespace private var namespace
    
    private var otherSessions: [Session] {
        clerk.client.sessions.filter({ $0.id != clerk.session?.id && $0.status == .active })
    }
    
    private func setActiveSession(_ session: Session) async {
        do {
            try await clerk.setActive(.init(sessionId: session.id, organizationId: nil))
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func signOut(_ session: Session? = nil) async {
        do {
            try await clerk.signOut(sessionId: session?.id)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    @State private var scaleCurrentSession = 1.0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let currentSession = clerk.session {
                    VStack(alignment: .leading, spacing: 20) {
                        UserPreviewView(session: currentSession)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button {
                            dismiss()
                            clerkUIState.userProfileIsPresented = true
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "gearshape")
                                    .frame(width: 50)
                                    .imageScale(.medium)
                                Text("Manage account")
                                    .font(.footnote)
                            }
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        
                        AsyncButton {
                            await signOut(currentSession)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .frame(width: 50)
                                    .imageScale(.medium)

                                Text("Sign out")
                                    .font(.footnote)
                            }
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                
                if !clerk.environment.authConfig.singleSessionMode {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(otherSessions) { session in
                            AsyncButton {
                                await setActiveSession(session)
                            } label: {
                                HStack {
                                    UserPreviewView(session: session)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Image(systemName: "arrow.left.arrow.right")
                                        .foregroundStyle(.secondary)
                                        .imageScale(.medium)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button {
                            dismiss()
                            clerkUIState.presentedAuthStep = .signInStart
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "plus")
                                    .frame(width: 50)
                                    .imageScale(.medium)

                                Text("Add account")
                                    .font(.footnote)
                            }
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.vertical)
                    .background(.quinary)
                    .overlay(alignment: .top, content: {
                        Divider()
                    })
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                    
                    if otherSessions.count > 0 {
                        AsyncButton {
                            await signOut()
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .frame(width: 50)
                                    .imageScale(.medium)

                                Text("Sign out of all accounts")
                                    .font(.footnote)
                            }
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
                
                SecuredByClerkView()
                    .opacity(0.4)
                    .frame(maxWidth: .infinity)
                    .padding(.top)
            }
            .animation(.snappy, value: clerk.session)
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: clerk.session) { session in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if session == nil { dismiss() }
            }
        }
        .dismissButtonOverlay()
        .clerkErrorPresenting($errorWrapper)
    }
}

#Preview {
    UserButtonPopover()
        .environmentObject(Clerk.mock)
}

#endif
