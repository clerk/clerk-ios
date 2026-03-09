//
//  UserProfileMfaAddTotpView+macOS.swift
//  Clerk
//

#if os(macOS)

import AppKit
import ClerkKit
import SwiftUI

struct UserProfileMfaAddTotpView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.dismiss) private var dismiss
  @Environment(\.clerkTheme) private var theme

  @State private var totp: TOTPResource?
  @State private var verificationCode = ""
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var backupCodes: [String]?

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Add Authenticator Application")
        .font(theme.fonts.title3.weight(.semibold))
        .foregroundStyle(theme.colors.foreground)

      if let backupCodes {
        BackupCodesView(backupCodes: backupCodes, mfaType: .authenticatorApp)
      } else {
        content
      }
    }
    .padding(24)
    .frame(minWidth: 500, maxWidth: 620, alignment: .leading)
    .background(theme.colors.background)
    .task {
      if totp == nil {
        await createTotp()
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    Text("Set up a new sign-in method in your authenticator app, then enter a verification code to finish linking your account.")
      .font(theme.fonts.body)
      .foregroundStyle(theme.colors.mutedForeground)
      .fixedSize(horizontal: false, vertical: true)

    if let secret = totp?.secret {
      detailBlock(title: "Secret", value: secret)
    }

    if let uri = totp?.uri {
      detailBlock(title: "TOTP URI", value: uri)
    }

    VStack(alignment: .leading, spacing: 6) {
      Text("Verification code")
        .font(theme.fonts.subheadline.weight(.medium))
        .foregroundStyle(theme.colors.foreground)

      TextField("Enter 6-digit code", text: $verificationCode)
        .textFieldStyle(.roundedBorder)
    }

    if let errorMessage {
      Text(errorMessage)
        .font(theme.fonts.footnote)
        .foregroundStyle(theme.colors.danger)
        .fixedSize(horizontal: false, vertical: true)
    }

    HStack {
      Button("Cancel") {
        dismiss()
      }
      .keyboardShortcut(.cancelAction)

      Spacer()

      Button("Verify") {
        Task {
          await verify()
        }
      }
      .buttonStyle(.primary())
      .disabled(isLoading || verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || totp == nil)
    }
  }
}

extension UserProfileMfaAddTotpView {
  private func detailBlock(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(theme.fonts.subheadline.weight(.medium))
        .foregroundStyle(theme.colors.foreground)

      Text(verbatim: value)
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.foreground)
        .textSelection(.enabled)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.muted, in: RoundedRectangle(cornerRadius: 12))

      Button("Copy to Clipboard") {
        copyToClipboard(value)
      }
      .buttonStyle(.secondary(config: .init(emphasis: .low)))
    }
  }

  private func copyToClipboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }

  @MainActor
  private func createTotp() async {
    guard let user else { return }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      totp = try await user.createTOTP()
    } catch {
      errorMessage = error.localizedDescription
      ClerkLogger.error("Failed to create TOTP", error: error)
    }
  }

  @MainActor
  private func verify() async {
    guard let user else { return }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let verifiedTotp = try await user.verifyTOTP(code: verificationCode.trimmingCharacters(in: .whitespacesAndNewlines))
      _ = try? await clerk.refreshClient()

      if let backupCodes = verifiedTotp.backupCodes, !backupCodes.isEmpty {
        self.backupCodes = backupCodes
      } else {
        dismiss()
      }
    } catch {
      errorMessage = error.localizedDescription
      ClerkLogger.error("Failed to verify TOTP", error: error)
    }
  }

  @MainActor
  private var user: User? {
    clerk.user
  }
}

#Preview {
  UserProfileMfaAddTotpView()
    .environment(Clerk.preview())
}

#endif
