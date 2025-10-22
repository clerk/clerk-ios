//
//  UserButtonAccountSwitcher.swift
//  Clerk
//
//  Created by Mike Pitre on 5/6/25.
//

#if os(iOS)

import SwiftUI

struct UserButtonAccountSwitcher: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.userProfileSharedState) private var sharedState
    @Environment(\.dismiss) private var dismiss

    @Binding private var contentHeight: CGFloat
    @State private var securedByClerkHeight: CGFloat = 0
    @State private var error: Error?

    var sessions: [Session] {
        (clerk.client?.sessions ?? [])
            .sorted { lhs, rhs in
                if lhs.id == clerk.session?.id {
                    return true
                } else if rhs.id == clerk.session?.id {
                    return false
                } else {
                    return false
                }
            }
    }

    func setActiveSession(_ session: Session) async {
        do {
            try await clerk.setActive(sessionId: session.id)
            dismiss()
        } catch {
            self.error = error
            ClerkLogger.error("Failed to set active session", error: error)
        }
    }

    func signOutOfAllAccounts() async {
        do {
            try await clerk.signOut()
        } catch {
            self.error = error
            ClerkLogger.error("Failed to sign out of all accounts", error: error)
        }
    }

    var extraContentHeight: CGFloat {
        if #available(iOS 26.0, *) {
            return 0
        } else {
            return 7
        }
    }

    init(contentHeight: Binding<CGFloat> = .constant(0)) {
        self._contentHeight = contentHeight
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(sessions) { session in
                            if let user = session.user {
                                AsyncButton {
                                    await setActiveSession(session)
                                } label: { isRunning in
                                    HStack {
                                        UserPreviewView(user: user)
                                        Spacer()
                                        if clerk.session?.id == session.id {
                                            Image("icon-check", bundle: .module)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 20, height: 20)
                                                .foregroundStyle(theme.colors.primary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 24)
                                    .frame(maxWidth: .infinity)
                                    .contentShape(.rect)
                                    .overlayProgressView(isActive: isRunning)
                                }
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundStyle(theme.colors.border)
                                }
                                .buttonStyle(.pressedBackground)
                                .disabled(clerk.session?.id == session.id)
                                .simultaneousGesture(TapGesture())
                            }
                        }

                        Button {
                            sharedState.accountSwitcherIsPresented = false
                            sharedState.authViewIsPresented = true
                        } label: {
                            UserProfileRowView(icon: "icon-plus", text: "Add account")
                        }
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(theme.colors.border)
                        }
                        .buttonStyle(.pressedBackground)
                        .simultaneousGesture(TapGesture())

                        AsyncButton {
                            await signOutOfAllAccounts()
                        } label: { isRunning in
                            UserProfileRowView(icon: "icon-sign-out", text: "Sign out of all accounts")
                                .overlayProgressView(isActive: isRunning)
                        }
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(theme.colors.border)
                        }
                        .buttonStyle(.pressedBackground)
                        .simultaneousGesture(TapGesture())
                    }
                    .onGeometryChange(
                        for: CGFloat.self,
                        of: { proxy in
                            proxy.size.height
                        },
                        action: { newValue in
                            contentHeight = newValue + UITabBarController().tabBar.frame.size.height + extraContentHeight
                        })
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .animation(.default, value: sessions)
            .clerkErrorPresenting($error)
            .navigationBarTitleDisplayMode(.inline)
            .preGlassSolidNavBar()
            .preGlassDetentSheetBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done", bundle: .module)
                            .font(theme.fonts.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(theme.colors.primary)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Switch account", bundle: .module)
                        .font(theme.fonts.headline)
                        .foregroundStyle(theme.colors.foreground)
                }
            }
        }
    }
}

#Preview {
    UserButtonAccountSwitcher()
        .environment(\.clerk, .mock)
        .environment(\.clerkTheme, .clerk)
}

#endif
