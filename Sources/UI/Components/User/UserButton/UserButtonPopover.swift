//
//  UserButtonPopover.swift
//
//
//  Created by Mike Pitre on 11/29/23.
//

#if os(iOS)

import SwiftUI

struct UserButtonPopover: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    @State private var errorWrapper: ErrorWrapper?
    @Namespace private var namespace
    
    private var otherSessions: [Session] {
        guard let client = clerk.client else { return [] }
        return client.sessions.filter({ $0.id != clerk.session?.id && $0.status == .active })
    }
    
    private func setActiveSession(_ session: Session) async {
        do {
            try await clerk.setActive(sessionId: session.id)
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
        
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .zero) {
                if let currentSession = clerk.session, let user = currentSession.user {
                    VStack(alignment: .leading, spacing: 8) {
                        UserPreviewView(user: user)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack {
                            Button {
                                dismiss()
                                clerkUIState.userProfileIsPresented = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "gearshape.fill")
                                        .frame(height: 16)
                                        .imageScale(.medium)
                                    Text("Manage account")
                                        .font(.footnote)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ClerkSecondaryButtonStyle())
                            
                            AsyncButton {
                                await signOut(currentSession)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .frame(height: 16)
                                        .imageScale(.medium)
                                    
                                    Text("Sign out")
                                        .font(.footnote)
                                }
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ClerkSecondaryButtonStyle())
                        }
                        .padding(.leading, 66) // 66 is 50pt avatar + 16pt spacing
                    }
                    .padding()
                    .padding(.top)
                    .background()
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                    .zIndex(10)
                }
                
                if clerk.environment?.authConfig.singleSessionMode == false {
                    VStack(alignment: .leading, spacing: .zero) {
                        ForEach(otherSessions) { session in
                            if let user = session.user {
                                AsyncButton {
                                    await setActiveSession(session)
                                } label: {
                                    HStack {
                                        UserPreviewView(user: user)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Image(systemName: "arrow.left.arrow.right")
                                            .foregroundStyle(clerkTheme.colors.textSecondary)
                                            .imageScale(.small)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                                .padding(.vertical)
                                .overlay(alignment: .bottom) {
                                    Divider()
                                }
                            }
                        }
                        
                        Button {
                            dismiss()
                            clerkUIState.presentedAuthStep = .signInStart
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "plus")
                                    .imageScale(.small)
                                    .padding(6)
                                    .clipShape(.circle)
                                    .frame(width: 50)
                                    .background {
                                        Circle()
                                            .foregroundStyle(.ultraThinMaterial)
                                    }
                                    .overlay(content: {
                                        Circle()
                                            .strokeBorder(clerkTheme.colors.borderPrimary, style: StrokeStyle(lineWidth: 2, dash: [4]))
                                    })
                                
                                Text("Add account")
                                    .font(.footnote.weight(.medium))
                            }
                            .foregroundStyle(clerkTheme.colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding()
                    }
                    
                    if otherSessions.count > 0 {
                        AsyncButton {
                            await signOut()
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .frame(width: 50)
                                    .imageScale(.small)
                                
                                Text("Sign out of all accounts")
                                    .font(.footnote.weight(.medium))
                            }
                            .foregroundStyle(clerkTheme.colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding()
                        .overlay(alignment: .bottom, content: {
                            Divider()
                        })
                        .zIndex(-1)
                    }
                }
            }
            .animation(.snappy, value: clerk.session)
            .frame(minWidth: 376, maxWidth: .infinity, alignment: .leading)
            .onChange(of: clerk.session) { session in
                FeedbackGenerator.success()
                if session == nil { dismiss() }
            }
        }
        .background()
        .dismissButtonOverlay()
        .clerkErrorPresenting($errorWrapper)
        .clerkBottomBranding()
    }
}

#Preview {
    UserButtonPopover()
}

#endif
