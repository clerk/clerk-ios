//
//  UserProfileView+macOS.swift
//  Clerk
//

#if os(macOS)

import ClerkKit
import SwiftUI

public struct UserProfileView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.dismiss) private var dismiss
  @Environment(\.clerkTheme) private var theme

  let isDismissable: Bool

  @State private var isEditProfilePresented = false
  @State private var isSecurityPresented = false
  @State private var isConnectAccountPresented = false
  @State private var isAccountSwitcherPresented = false
  @State private var isAddAccountPresented = false
  @State private var isSigningOut = false
  @State private var errorMessage: String?

  public init(isDismissable: Bool = true) {
    self.isDismissable = isDismissable
  }

  public var body: some View {
    Group {
      if let user = clerk.user {
        VStack(alignment: .leading, spacing: 20) {
          header(for: user)

          GroupBox("Account") {
            VStack(alignment: .leading, spacing: 10) {
              detailRow("User ID", user.id)
              detailRow("Email", user.primaryEmailAddress?.emailAddress ?? "Missing")
              detailRow("Username", user.username ?? "Missing")
              detailRow("Session", clerk.session?.id ?? "Missing")
              detailRow("Status", clerk.session.map { String(describing: $0.status) } ?? "Missing")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }

          if clerk.environment?.mutliSessionModeIsEnabled == true {
            sessionManagementSection
          }

          if !user.externalAccounts.isEmpty {
            GroupBox("Connected Accounts") {
              VStack(alignment: .leading, spacing: 12) {
                ForEach(user.externalAccounts) { account in
                  UserProfileExternalAccountRow(externalAccount: account)
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
          }

          if !unconnectedProviders.isEmpty {
            HStack {
              Spacer()

              Button("Connect Account") {
                isConnectAccountPresented = true
              }
            }
          }

          if let errorMessage {
            Text(errorMessage)
              .font(theme.fonts.footnote)
              .foregroundStyle(theme.colors.danger)
              .fixedSize(horizontal: false, vertical: true)
          }

          HStack {
            if isDismissable {
              Button("Close") {
                dismiss()
              }
              .keyboardShortcut(.cancelAction)
            }

            Spacer()

            Button("Sign Out") {
              Task {
                await signOut()
              }
            }
            .buttonStyle(.secondary(config: .init(emphasis: .low)))
            .disabled(isSigningOut)
          }
        }
        .padding(24)
        .frame(minWidth: 420, maxWidth: 520, alignment: .leading)
        .background(theme.colors.background)
        .task {
          _ = try? await clerk.refreshClient()
        }
        .task {
          _ = try? await clerk.refreshEnvironment()
        }
        .task {
          for await event in clerk.auth.events {
            switch event {
            case .signInCompleted, .signUpCompleted:
              isAddAccountPresented = false
            default:
              break
            }
          }
        }
        .sheet(isPresented: $isConnectAccountPresented) {
          UserProfileAddConnectedAccountView()
        }
        .sheet(isPresented: $isEditProfilePresented) {
          UserProfileUpdateProfileView(user: user)
        }
        .sheet(isPresented: $isSecurityPresented) {
          UserProfileSecurityView()
        }
        .sheet(isPresented: $isAccountSwitcherPresented) {
          UserButtonAccountSwitcher {
            isAddAccountPresented = true
          }
        }
        .sheet(isPresented: $isAddAccountPresented) {
          AuthView()
        }
        .onChange(of: clerk.user) { _, newValue in
          guard newValue == nil, isDismissable else { return }
          dismiss()
        }
      } else {
        VStack(alignment: .leading, spacing: 16) {
          Text("No signed-in user is available.")
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.mutedForeground)

          if isDismissable {
            HStack {
              Spacer()

              Button("Close") {
                dismiss()
              }
            }
          }
        }
        .padding(24)
        .frame(minWidth: 420, maxWidth: 520, alignment: .leading)
        .background(theme.colors.background)
      }
    }
  }
}

extension UserProfileView {
  private var sessionManagementSection: some View {
    GroupBox("Session Management") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Use multiple signed-in accounts on this Mac and switch the active session when needed.")
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.mutedForeground)
          .fixedSize(horizontal: false, vertical: true)

        Text("Adding a provider for the current Clerk user will appear under Connected Accounts. Switch Account only appears after you sign in as a different Clerk user and the client has more than one session.")
          .font(theme.fonts.footnote)
          .foregroundStyle(theme.colors.mutedForeground)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 10) {
          if clerk.auth.sessions.count > 1 {
            Button("Switch Account") {
              isAccountSwitcherPresented = true
            }
            .buttonStyle(.secondary(config: .init(emphasis: .low)))
          }

          Button("Add Account") {
            isAddAccountPresented = true
          }
          .buttonStyle(.secondary(config: .init(emphasis: .low)))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var unconnectedProviders: [OAuthProvider] {
    clerk.user?.unconnectedProviders ?? []
  }

  private func header(for user: User) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 14) {
        UserButtonAvatarView(imageUrl: user.imageUrl)
          .frame(width: 56, height: 56)

        VStack(alignment: .leading, spacing: 4) {
          Text(primaryLabel(for: user))
            .font(theme.fonts.title3.weight(.semibold))
            .foregroundStyle(theme.colors.foreground)

          if let secondary = secondaryLabel(for: user) {
            Text(secondary)
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.mutedForeground)
              .textSelection(.enabled)
          }
        }
      }

      HStack(spacing: 10) {
        if canEditProfile {
          Button("Edit Profile") {
            isEditProfilePresented = true
          }
          .buttonStyle(.secondary(config: .init(emphasis: .low)))
        }

        Button("Security") {
          isSecurityPresented = true
        }
        .buttonStyle(.secondary(config: .init(emphasis: .low)))
      }
    }
  }

  private var canEditProfile: Bool {
    clerk.environment?.userSettings.attributes.contains(where: { key, value in
      ["username", "first_name", "last_name"].contains(key) && value.enabled
    }) == true
  }

  private func primaryLabel(for user: User) -> String {
    let fullName = [user.firstName, user.lastName]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")

    if !fullName.isEmpty {
      return fullName
    }

    if let username = user.username, !username.isEmpty {
      return username
    }

    return user.primaryEmailAddress?.emailAddress ?? user.id
  }

  private func secondaryLabel(for user: User) -> String? {
    if let username = user.username, !username.isEmpty,
       let emailAddress = user.primaryEmailAddress?.emailAddress,
       username != emailAddress
    {
      return emailAddress
    }

    return user.primaryEmailAddress?.emailAddress
  }

  private func detailRow(_ title: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .font(theme.fonts.subheadline.weight(.medium))
        .foregroundStyle(theme.colors.foreground)
        .frame(width: 72, alignment: .leading)

      Text(value)
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.mutedForeground)
        .textSelection(.enabled)
    }
  }

  @MainActor
  private func signOut() async {
    isSigningOut = true
    errorMessage = nil
    defer { isSigningOut = false }

    do {
      guard let sessionId = clerk.session?.id else {
        if isDismissable {
          dismiss()
        }
        return
      }

      try await clerk.auth.signOut(sessionId: sessionId)
      if clerk.session == nil, isDismissable {
        dismiss()
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

#Preview("Signed In") {
  UserProfileView()
    .environment(Clerk.preview())
}

#endif
