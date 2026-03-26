//
//  UserButtonAccountSwitcher.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct UserButtonAccountSwitcher: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(UserProfileSheetNavigation.self) private var navigation
  @Environment(\.dismiss) private var dismiss

  @Binding private var contentHeight: CGFloat
  @State private var error: Error?

  private var sessions: [Session] {
    clerk.auth.sessions
      .sorted { lhs, rhs in
        if lhs.id == clerk.session?.id {
          true
        } else if rhs.id == clerk.session?.id {
          false
        } else {
          false
        }
      }
  }

  @MainActor
  private func setActiveSession(_ session: Session) async {
    do {
      try await clerk.auth.setActive(sessionId: session.id, organizationId: session.lastActiveOrganizationId)
      dismiss()
    } catch {
      self.error = error
      ClerkLogger.error("Failed to set active session", error: error)
    }
  }

  @MainActor
  private func signOutOfAllAccounts() async {
    do {
      try await clerk.auth.signOut()
    } catch {
      self.error = error
      ClerkLogger.error("Failed to sign out of all accounts", error: error)
    }
  }

  #if os(iOS)
  private var extraContentHeight: CGFloat {
    if #available(iOS 26.0, *) {
      0
    } else {
      7
    }
  }
  #endif

  init(contentHeight: Binding<CGFloat> = .constant(0)) {
    _contentHeight = contentHeight
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
                .accessibilityIdentifier(ClerkAccessibilityIdentifiers.AccountSwitcher.sessionButton(userID: user.id))
                .buttonStyle(.pressedBackground)
                .disabled(clerk.session?.id == session.id)
                .simultaneousGesture(TapGesture())
              }
            }

            Button {
              navigation.accountSwitcherIsPresented = false
              navigation.authViewIsPresented = true
            } label: {
              UserProfileRowView(icon: "icon-plus", text: "Add account")
            }
            .overlay(alignment: .bottom) {
              Rectangle()
                .frame(height: 1)
                .foregroundStyle(theme.colors.border)
            }
            .accessibilityIdentifier(ClerkAccessibilityIdentifiers.AccountSwitcher.addAccountButton)
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
            .accessibilityIdentifier(ClerkAccessibilityIdentifiers.AccountSwitcher.signOutAllButton)
            .buttonStyle(.pressedBackground)
            .simultaneousGesture(TapGesture())
          }
          .onGeometryChange(
            for: CGFloat.self,
            of: { proxy in
              proxy.size.height
            },
            action: { newValue in
              #if os(iOS)
              contentHeight = newValue + UITabBarController().tabBar.frame.size.height + extraContentHeight
              #elseif os(macOS)
              _ = newValue
              #endif
            }
          )
        }
      }
      .animation(.default, value: sessions)
      .clerkErrorPresenting($error)
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
        .preGlassSolidNavBar()
        .preGlassDetentSheetBackground()
        .toolbar {
          ToolbarItem(
            placement: {
              #if os(iOS)
              .topBarTrailing
              #elseif os(macOS)
              .cancellationAction
              #endif
            }()
          ) {
            Button {
              dismiss()
            } label: {
              Text("Done", bundle: .module)
                .font(theme.fonts.body)
                .fontWeight(.semibold)
                .foregroundStyle(theme.colors.primary)
            }
            .accessibilityIdentifier(ClerkAccessibilityIdentifiers.AccountSwitcher.doneButton)
          }

          ToolbarItem(placement: .principal) {
            Text("Switch account", bundle: .module)
              .font(theme.fonts.headline)
              .foregroundStyle(theme.colors.foreground)
          }
        }
    }
    #if os(macOS)
    .frame(minWidth: 420, maxWidth: 520)
    #endif
  }
}

#Preview {
  UserButtonAccountSwitcher()
    .clerkPreview()
    .environment(UserProfileSheetNavigation())
    .environment(\.clerkTheme, .clerk)
}

#endif
