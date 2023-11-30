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
    
    private var otherSessions: [Session] {
        clerk.client.sessions.filter({ $0.id != clerk.session?.id })
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let currentSession = clerk.session {
                    VStack(alignment: .leading, spacing: 20) {
                        UserPreviewView(session: currentSession)
                        
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
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            //
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .frame(width: 50)
                                    .imageScale(.medium)

                                Text("Sign out")
                                    .font(.footnote)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                
                if !clerk.environment.authConfig.singleSessionMode {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(otherSessions) { session in
                            UserPreviewView(session: session)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                    .padding()
                    .background(.quinary)
                    .overlay(alignment: .top, content: {
                        Divider()
                    })
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                    
                    Button {
                        //
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .frame(width: 50)
                                .imageScale(.medium)

                            Text("Sign out of all accounts")
                                .font(.footnote)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                
                SecuredByClerkView()
                    .opacity(0.4)
                    .frame(maxWidth: .infinity)
                    .padding(.top)
            }
            .padding(.vertical)
            .padding(.vertical)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    UserButtonPopover()
        .environmentObject(Clerk.mock)
}

#endif
