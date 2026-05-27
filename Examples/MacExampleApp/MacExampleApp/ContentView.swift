//
//  ContentView.swift
//  MacExampleApp
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct ContentView: View {
  @Environment(Clerk.self) private var clerk
  @State private var authIsPresented = false
  @State private var authMode: AuthView.Mode = .signInOrUp
  @State private var isRefreshing = false
  @State private var lastRefreshError: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Mac Example App")
        .font(.largeTitle.weight(.semibold))

      Text("A native macOS harness for validating Clerk package behavior across signed-out, signed-in, and organization flows.")
        .foregroundStyle(.secondary)
        .frame(maxWidth: 520, alignment: .leading)

      GroupBox("Clerk State") {
        VStack(alignment: .leading, spacing: 12) {
          statusRow("Instance Type", String(describing: clerk.instanceType))
          statusRow("Publishable Key", clerk.publishableKey)
          statusRow("Is Loaded", clerk.isLoaded ? "Yes" : "No")
          statusRow("Environment", clerk.environment == nil ? "Missing" : "Loaded")
          statusRow("Client", clerk.client?.id ?? "Missing")
          statusRow("Session", clerk.session?.id ?? "Missing")
          statusRow("Session Status", clerk.session.map { String(describing: $0.status) } ?? "Missing")
          statusRow("User", clerk.user?.id ?? "Missing")
        }
        .textSelection(.enabled)
      }

      GroupBox("Manual Auth Coverage") {
        VStack(alignment: .leading, spacing: 12) {
          Picker("Auth Mode", selection: $authMode) {
            Text("Sign In or Up").tag(AuthView.Mode.signInOrUp)
            Text("Sign In").tag(AuthView.Mode.signIn)
            Text("Sign Up").tag(AuthView.Mode.signUp)
          }
          .pickerStyle(.segmented)

          statusRow("Visible Providers", visibleProviderNames)
          statusRow("Passkey Button", showsPasskeyButton ? "Available" : "Unavailable")

          Text("Use this section to exercise auth modes, provider visibility, passkeys, and session-task routing.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: 520, alignment: .leading)
        }
      }

      HStack(spacing: 12) {
        UserButton {
          Button("Open AuthView") {
            authIsPresented = true
          }
          .buttonStyle(.borderedProminent)
          .disabled(isRefreshing)
        }
        .disabled(isRefreshing)

        OrganizationSwitcher()

        Button("Refresh Environment") {
          Task {
            await refreshEnvironment()
          }
        }
        .buttonStyle(.bordered)
        .disabled(isRefreshing)

        Button("Refresh Client") {
          Task {
            await refreshClient()
          }
        }
        .buttonStyle(.bordered)
        .disabled(isRefreshing)

        if isRefreshing {
          ProgressView()
            .controlSize(.small)
        }
      }

      if let lastRefreshError {
        Text(lastRefreshError)
          .foregroundStyle(.red)
          .frame(maxWidth: 520, alignment: .leading)
      } else {
        Text("`AuthView()`, `UserButton()`, `UserProfileView()`, and organization prebuilt views are available here for native macOS validation.")
          .foregroundStyle(.secondary)
          .frame(maxWidth: 520, alignment: .leading)
      }
    }
    .padding(32)
    .frame(minWidth: 640, minHeight: 440)
    .sheet(isPresented: $authIsPresented) {
      AuthView(mode: authMode)
    }
  }

  private func statusRow(_ title: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .fontWeight(.medium)
        .frame(width: 140, alignment: .leading)

      Text(value)
        .foregroundStyle(.secondary)
    }
  }

  private var visibleProviderNames: String {
    let providerNames = clerk.environment?.userSettings.social.values
      .filter { config in
        config.enabled && config.authenticatable && !config.notSelectable
      }
      .map(\.name)
      .sorted { lhs, rhs in
        lhs.localizedStandardCompare(rhs) == .orderedAscending
      }

    guard let providerNames, !providerNames.isEmpty else {
      return "None"
    }

    return providerNames.joined(separator: ", ")
  }

  private var showsPasskeyButton: Bool {
    authMode != .signUp && (clerk.environment?.userSettings.passkeySettings?.showSignInButton ?? false)
  }

  @MainActor
  private func refreshEnvironment() async {
    isRefreshing = true
    defer { isRefreshing = false }

    do {
      _ = try await clerk.refreshEnvironment()
      lastRefreshError = nil
    } catch {
      lastRefreshError = error.localizedDescription
    }
  }

  @MainActor
  private func refreshClient() async {
    isRefreshing = true
    defer { isRefreshing = false }

    do {
      _ = try await clerk.refreshClient()
      lastRefreshError = nil
    } catch {
      lastRefreshError = error.localizedDescription
    }
  }
}

#Preview("Signed Out") {
  ContentView()
    .environment(Clerk.preview { preview in
      preview.isSignedIn = false
    })
}

#Preview("Signed In") {
  ContentView()
    .environment(Clerk.preview())
}
