//
//  UserButtonAccountSwitcher+macOS.swift
//  Clerk
//

#if os(macOS)

import ClerkKit
import SwiftUI

struct UserButtonAccountSwitcher: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.dismiss) private var dismiss
  @Environment(\.clerkTheme) private var theme

  let onAddAccount: () -> Void

  @State private var activeSessionId: String?
  @State private var isSigningOutAllAccounts = false
  @State private var errorMessage: String?

  init(onAddAccount: @escaping () -> Void = {}) {
    self.onAddAccount = onAddAccount
  }

  private var sessions: [Session] {
    clerk.auth.sessions.sorted { lhs, rhs in
      if lhs.id == clerk.session?.id {
        return true
      }

      if rhs.id == clerk.session?.id {
        return false
      }

      return lhs.lastActiveAt > rhs.lastActiveAt
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      header

      if sessions.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("No available sessions")
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.foreground)

          Text("Sign in to another account to enable account switching.")
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.mutedForeground)
        }
      } else {
        sessionsList
      }

      if let errorMessage {
        Text(errorMessage)
          .font(theme.fonts.footnote)
          .foregroundStyle(theme.colors.danger)
          .fixedSize(horizontal: false, vertical: true)
      }

      footer
    }
    .padding(24)
    .frame(minWidth: 420, maxWidth: 520, alignment: .leading)
  }
}

extension UserButtonAccountSwitcher {
  fileprivate var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Switch account")
        .font(theme.fonts.title3.weight(.semibold))
        .foregroundStyle(theme.colors.foreground)

      Text("Choose which active session should be used on this Mac, or sign out of all accounts.")
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.mutedForeground)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  fileprivate var sessionsList: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(sessions) { session in
        if let user = session.user {
          sessionRow(for: session, user: user)
        }
      }
    }
  }

  fileprivate func sessionRow(for session: Session, user: User) -> some View {
    let isActiveSession = clerk.session?.id == session.id
    let isRunning = activeSessionId == session.id

    return Button {
      Task {
        await setActiveSession(session)
      }
    } label: {
      HStack(spacing: 14) {
        UserButtonAvatarView(imageUrl: user.imageUrl)
          .frame(width: 44, height: 44)

        VStack(alignment: .leading, spacing: 4) {
          Text(primaryLabel(for: user))
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.foreground)

          if let secondaryLabel = secondaryLabel(for: user) {
            Text(secondaryLabel)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.mutedForeground)
          }
        }

        Spacer()

        if isRunning {
          SpinnerView(color: theme.colors.primary)
            .frame(width: 16, height: 16)
        } else if isActiveSession {
          Label("Current", systemImage: "checkmark.circle.fill")
            .font(theme.fonts.subheadline.weight(.medium))
            .foregroundStyle(theme.colors.primary)
        }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(theme.colors.muted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(
            isActiveSession ? theme.colors.inputBorderFocused : theme.colors.border,
            lineWidth: 1
          )
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(isActiveSession || isRunning || isSigningOutAllAccounts)
  }

  fileprivate var footer: some View {
    HStack {
      Button("Close") {
        dismiss()
      }
      .buttonStyle(.secondary(config: .init(emphasis: .low, size: .small)))
      .keyboardShortcut(.cancelAction)

      Spacer()

      if clerk.environment?.mutliSessionModeIsEnabled == true {
        Button("Add Account") {
          dismiss()
          Task { @MainActor in
            await Task.yield()
            onAddAccount()
          }
        }
        .buttonStyle(.secondary(config: .init(emphasis: .low)))
        .disabled(isSigningOutAllAccounts || activeSessionId != nil)
      }

      Button("Sign Out All") {
        Task {
          await signOutOfAllAccounts()
        }
      }
      .buttonStyle(.negative())
      .disabled(isSigningOutAllAccounts || activeSessionId != nil)
    }
  }

  fileprivate func primaryLabel(for user: User) -> String {
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

  fileprivate func secondaryLabel(for user: User) -> String? {
    if let username = user.username, !username.isEmpty,
       let emailAddress = user.primaryEmailAddress?.emailAddress,
       username != emailAddress
    {
      return emailAddress
    }

    return user.primaryEmailAddress?.emailAddress
  }

  @MainActor
  fileprivate func setActiveSession(_ session: Session) async {
    activeSessionId = session.id
    errorMessage = nil
    defer { activeSessionId = nil }

    do {
      try await clerk.auth.setActive(sessionId: session.id)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
      ClerkLogger.error("Failed to set active session", error: error)
    }
  }

  @MainActor
  fileprivate func signOutOfAllAccounts() async {
    isSigningOutAllAccounts = true
    errorMessage = nil
    defer { isSigningOutAllAccounts = false }

    do {
      try await clerk.auth.signOut()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
      ClerkLogger.error("Failed to sign out of all accounts", error: error)
    }
  }
}

#Preview("Signed In") {
  UserButtonAccountSwitcher()
    .environment(Clerk.preview())
}

#endif
