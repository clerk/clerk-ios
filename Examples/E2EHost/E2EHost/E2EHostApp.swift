//
//  E2EHostApp.swift
//  E2EHost
//

import ClerkKit
import ClerkKitUI
import SwiftUI

@main
struct E2EHostApp: App {
  private let configuration = E2EConfiguration()

  @State private var clerk: Clerk?
  @State private var error: String?

  var body: some Scene {
    WindowGroup {
      Group {
        if let clerk {
          E2EHostView(configuration: configuration)
            .prefetchClerkImages()
            .environment(clerk)
        } else if let error {
          Text(error).accessibilityIdentifier("connection_error")
        } else {
          ProgressView("Connecting…")
        }
      }
      .task {
        guard clerk == nil else { return }
        do { clerk = try await configuration.connect() }
        catch is CancellationError { return }
        catch { self.error = error.localizedDescription }
      }
    }
  }
}
