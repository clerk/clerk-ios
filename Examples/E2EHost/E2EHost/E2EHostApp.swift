//
//  E2EHostApp.swift
//  E2EHost
//

import ClerkKit
import ClerkKitUI
import SwiftUI

@main
struct E2EHostApp: App {
  @State private var connection = E2EHostConnection()

  var body: some Scene {
    WindowGroup {
      Group {
        if let clerk = connection.clerk {
          E2EHostView(configuration: connection.configuration)
            .prefetchClerkImages()
            .environment(clerk)
        } else if let error = connection.error {
          ContentUnavailableView {
            Label("Unable to connect", systemImage: "wifi.exclamationmark")
          } description: {
            Text(error)
          } actions: {
            Button("Retry") { Task { await connection.connect() } }
          }
        } else {
          ProgressView("Connecting…")
        }
      }
      .task { await connection.connect() }
      .onOpenURL { url in Task { await connection.handle(url) } }
      .alert("Unable to complete authentication", isPresented: Binding(
        get: { connection.callbackError != nil },
        set: { if !$0 { connection.callbackError = nil } }
      )) {
        Button("OK") { connection.callbackError = nil }
      } message: {
        Text(connection.callbackError ?? "")
      }
    }
  }
}

@MainActor @Observable
private final class E2EHostConnection {
  let configuration = E2EConfiguration()
  private(set) var clerk: Clerk?
  private(set) var error: String?
  private let authentication = AppleAuthentication {
    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap(\.windows).first(where: \.isKeyWindow) ?? UIWindow()
  }

  private var isConnecting = false
  var callbackError: String?
  private var pendingURLs: [URL] = []
  private var isHandlingCallbacks = false

  func handle(_ url: URL) async {
    pendingURLs.append(url)
    await drainCallbacks()
  }

  private func drainCallbacks() async {
    guard let clerk, !isHandlingCallbacks else { return }
    isHandlingCallbacks = true
    defer { isHandlingCallbacks = false }
    while !pendingURLs.isEmpty {
      let url = pendingURLs.removeFirst()
      do { _ = try await clerk.handleAuthCallback(url) }
      catch { callbackError = error.localizedDescription }
    }
  }

  func connect() async {
    guard clerk == nil, !isConnecting else { return }
    isConnecting = true
    error = nil
    defer { isConnecting = false }
    do {
      clerk = try await configuration.connect(authentication: authentication)
      await drainCallbacks()
    } catch is CancellationError {
      return
    } catch {
      self.error = error.localizedDescription
    }
  }
}
