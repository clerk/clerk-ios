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
        
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .zero) {
                if let currentSession = clerk.session {
                    VStack(alignment: .leading, spacing: 8) {
                        UserPreviewView(session: currentSession)
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
                    .padding(.top, 30)
                    .background()
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                    .zIndex(10)
                }
                
                if !clerk.environment.authConfig.singleSessionMode {
                    VStack(alignment: .leading, spacing: .zero) {
                        ForEach(otherSessions) { session in
                            AsyncButton {
                                await setActiveSession(session)
                            } label: {
                                HStack {
                                    UserPreviewView(session: session)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Image(systemName: "arrow.left.arrow.right")
                                        .foregroundStyle(.secondary)
                                        .imageScale(.small)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            .padding(.vertical)
                            .background()
                            .overlay(alignment: .bottom) {
                                Divider()
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
                                            .strokeBorder(.quinary, style: StrokeStyle(lineWidth: 2, dash: [4]))
                                    })
                                
                                Text("Add account")
                                    .font(.footnote.weight(.medium))
                            }
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding()
                        .background {
                            Color(.systemBackground)
                                .raisedCardBottom()
                                .ignoresSafeArea()
                        }
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
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding()
                        .zIndex(-1)
                    }
                }
            }
            .animation(.snappy, value: clerk.session)
            .frame(minWidth: 376, maxWidth: .infinity, alignment: .leading)
            .onChange(of: clerk.session) { session in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if session == nil { dismiss() }
            }
        }
        .background(.ultraThinMaterial)
        .dismissButtonOverlay()
        .clerkErrorPresenting($errorWrapper)
        .clerkBottomBranding(withRaisedCardContent: false)
    }
}

#Preview {
    UserButtonPopover()
        .environmentObject(Clerk.mock)
}

#endif
