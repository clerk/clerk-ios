//
//  QuickstartApp.swift
//  Quickstart
//

import ClerkKit
import ClerkKitUI
import SwiftUI

@main
struct QuickstartApp: App {
  @State private var connection = QuickstartConnection()

  var body: some Scene {
    WindowGroup {
      Group {
        if let clerk = connection.clerk {
          ContentView()
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
      .atlantisProxy()
    }
  }
}

@MainActor @Observable
private final class QuickstartConnection {
  private(set) var clerk: Clerk?
  private(set) var error: String?
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
      let configuration = try ClerkConfiguration(
        publishableKey: QuickstartLocalSecrets.load().publishableKey ?? "",
        callbackURL: URL(string: "com.clerk.Quickstart://oauth/callback")!
      )
      clerk = try await Clerk.connect(configuration: configuration)
      await drainCallbacks()
    } catch is CancellationError {
      return
    } catch {
      self.error = error.localizedDescription
    }
  }
}
