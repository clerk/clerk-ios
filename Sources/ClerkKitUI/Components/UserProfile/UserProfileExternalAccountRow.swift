//
//  UserProfileExternalAccountRow.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import NukeUI
import SwiftUI

struct UserProfileExternalAccountRow: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkUserProfileOAuthConfig) private var oauthConfig
  @Environment(\.clerkTheme) private var theme

  @State private var removeResource: RemoveResource?
  @State private var isConfirmingRemoval = false
  @State private var isLoading = false
  @State private var error: Error?

  private var user: User? {
    clerk.user
  }

  let externalAccount: ExternalAccount

  var body: some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        WrappingHStack(alignment: .leading) {
          HStack(spacing: 8) {
            LazyImage(url: externalAccount.oauthProvider.iconImageUrl) { state in
              if let image = state.image {
                ProviderIconView(
                  provider: externalAccount.oauthProvider,
                  image: image
                )
              } else {
                #if DEBUG
                Image(systemName: "globe")
                  .resizable()
                  .scaledToFit()
                #endif
              }
            }
            .frame(width: 20, height: 20)
            .transition(.opacity.animation(.easeInOut(duration: 0.25)))

            Text(externalAccount.oauthProvider.name)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.mutedForeground)
              .lineLimit(1)
              .truncationMode(.tail)
              .frame(minHeight: 20)
          }
        }

        if !externalAccount.emailAddress.isEmpty {
          Text(externalAccount.emailAddress)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.foreground)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(minHeight: 22)
        }

        if let error = externalAccount.verification?.error {
          ErrorText(text: verificationErrorText(for: error), alignment: .leading)
          #if os(iOS)
            .font(theme.fonts.footnote)
          #elseif os(macOS)
            .fixedSize(horizontal: false, vertical: true)
          #endif
        }
      }

      Spacer()

      Menu {
        if externalAccount.verification?.error != nil || oauthConfig.shouldOfferReconnect(for: externalAccount) {
          AsyncButton {
            await reconnect()
          } label: { _ in
            Text("Reconnect", bundle: .module)
          }
          .onIsRunningChanged { isLoading = $0 }
          .onDisappear { isLoading = false }
        }

        Button(role: .destructive) {
          removeResource = .externalAccount(externalAccount)
        } label: {
          Text("Remove connection", bundle: .module)
        }

      } label: {
        ThreeDotsMenuLabel()
      }
      .frame(width: 30, height: 30)
      .menuIndicator(.hidden)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .background(theme.colors.background)
    .overlayProgressView(isActive: isLoading)
    .overlay(alignment: .bottom) {
      Rectangle()
        .frame(height: 1)
        .foregroundStyle(theme.colors.border)
    }
    .clerkErrorPresenting($error)
    .onChange(of: removeResource) {
      if $1 != nil { isConfirmingRemoval = true }
    }
    .confirmationDialog(
      removeResource?.messageLine1 ?? "",
      isPresented: $isConfirmingRemoval,
      titleVisibility: .visible,
      actions: {
        AsyncButton(role: .destructive) {
          await removeResource(removeResource)
        } label: { _ in
          Text(removeResource?.title ?? "", bundle: .module)
        }
        .onIsRunningChanged { isLoading = $0 }

        Button(role: .cancel) {
          isConfirmingRemoval = false
          removeResource = nil
        } label: {
          Text("Cancel", bundle: .module)
        }
      }
    )
  }
}

extension UserProfileExternalAccountRow {
  private static let reconnectableVerificationErrorCodes: Set<String> = [
    "external_account_missing_refresh_token",
    "oauth_fetch_user_error",
    "oauth_token_exchange_error",
    "external_account_email_address_verification_required",
  ]

  private func verificationErrorText(for error: ClerkAPIError) -> Text {
    if Self.reconnectableVerificationErrorCodes.contains(error.code) {
      return Text("This account has been disconnected.", bundle: .module)
    }

    return Text(verbatim: error.localizedDescription)
  }

  private func reconnect() async {
    guard let user else { return }

    let provider = externalAccount.oauthProvider
    let scopes = oauthConfig.additionalScopes(for: provider)
    let prompts = oauthConfig.prompts(for: provider)

    do {
      // Use prepareReauthorization when additional scopes are needed, even if
      // there is a verification error — reauthorization preserves the existing
      // account while upserting scopes. Only create a fresh external account
      // when there is a verification error and no scope reauthorization is required.
      let account: ExternalAccount = if !oauthConfig.requiresReauthorization(for: externalAccount),
                                        externalAccount.verification?.error != nil
      {
        try await user.createExternalAccount(
          provider: provider,
          additionalScopes: scopes,
          oidcPrompts: prompts
        )
      } else {
        try await externalAccount.prepareReauthorization(
          additionalScopes: scopes,
          oidcPrompts: prompts
        )
      }
      try await account.reauthorize()
    } catch {
      if error.isUserCancelledError { return }
      self.error = error
      ClerkLogger.error("Failed to reconnect external account", error: error)
    }
  }

  private func removeResource(_ resource: RemoveResource?) async {
    defer { removeResource = nil }

    do {
      try await resource?.deleteAction()
    } catch {
      self.error = error
      ClerkLogger.error("Failed to remove external account resource", error: error)
    }
  }
}

#Preview {
  #if os(iOS)
  UserProfileExternalAccountRow(externalAccount: .mockVerified)
  #elseif os(macOS)
  UserProfileExternalAccountRow(externalAccount: .mockVerified)
    .environment(Clerk.preview())
    .padding()
  #endif
}

#endif
