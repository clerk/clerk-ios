#if os(iOS)

import ClerkKit
@testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct UpdateRequiredAccessibilityTests {
  @Test
  func theUpdateScreensButtonsCanBeActivatedWithVoiceOver() async throws {
    let status = Clerk.AppVersionSupportStatus(
      isSupported: false,
      currentVersion: "1.0",
      minimumVersion: "2.0",
      updateURL: URL(string: "https://apps.apple.com/app/id1234567890")
    )
    let opened = OpenedURLs()
    let host = try await AccessibilityHost(
      UpdateRequiredContentView(status: status, appName: "Acme", supportEmail: "support@example.com")
        .environment(Clerk.mock)
        .environment(\.openURL, OpenURLAction { url in
          opened.urls.append(url)
          return .handled
        })
    )
    defer { host.close() }

    let store = try #require(host.element(labeled: "Go to App Store"))
    #expect(store.accessibilityTraits.contains(.button))
    #expect(store.accessibilityActivate())
    try await host.settle()
    #expect(opened.urls == [status.updateURL])

    let help = try #require(host.element(labeled: "Can't update?, Get Help"))
    #expect(help.accessibilityTraits.contains(.button))
    #expect(help.accessibilityActivate())
    try await host.settle()
    #expect(opened.urls.last == URL(string: "mailto:support@example.com"))
  }
}

@MainActor
private final class OpenedURLs {
  var urls: [URL?] = []
}

#endif
