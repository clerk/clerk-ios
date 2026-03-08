//
//  ContentView.swift
//  MacExampleApp
//

import ClerkKit
import SwiftUI

struct ContentView: View {
  @Environment(Clerk.self) private var clerk
  @State private var isRefreshing = false
  @State private var lastRefreshError: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Mac Example App")
        .font(.largeTitle.weight(.semibold))

      Text("A native macOS harness for validating Clerk package behavior while macOS support is being built out.")
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

      HStack(spacing: 12) {
        Button("Refresh Environment") {
          Task {
            await refreshEnvironment()
          }
        }
        .buttonStyle(.borderedProminent)
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
        Text("ClerkKitUI prebuilt views such as AuthView and UserButton are currently iOS-only. Use this app as the native macOS launch target while that support is added.")
          .foregroundStyle(.secondary)
          .frame(maxWidth: 520, alignment: .leading)
      }
    }
    .padding(32)
    .frame(minWidth: 640, minHeight: 440)
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
