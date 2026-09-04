#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@MainActor
struct DevelopmentFooterSnapshotTests {
  @Test
  func developmentFooterRemainsVisibleWhenTheHostConsumesTheSafeArea() {
    let clerk = Clerk.mockSignedOut
    clerk.environment?.displayConfig.showDevmodeWarning = true
    let content = Color.white
      .authFooter()
      .environment(clerk)
      .environment(\.clerkFooterHostBottomInset, 34)
      .environment(\.colorScheme, .light)
      .environment(\.dynamicTypeSize, .large)
      .environment(\.locale, Locale(identifier: "en_US"))
      .frame(width: 402, height: 160)
      .clipped()
      .background(Color.white)

    assertSnapshot(
      of: content,
      as: .image(
        precision: 0.99,
        perceptualPrecision: 0.98,
        layout: .fixed(width: 402, height: 160),
        traits: UITraitCollection(displayScale: 3)
      )
    )
  }
}

#endif
