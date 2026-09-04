#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import SwiftUI
import Testing

@MainActor
struct AuthFooterSnapshotTests {
  @Test(arguments: [
    ("no-bottom-safe-area-light", ColorScheme.light, DynamicTypeSize.large, 0.0),
    ("no-bottom-safe-area-dark", ColorScheme.dark, DynamicTypeSize.large, 0.0),
    ("no-bottom-safe-area-accessibility", ColorScheme.light, DynamicTypeSize.accessibility3, 0.0),
    ("bottom-safe-area", ColorScheme.light, DynamicTypeSize.large, 34.0),
  ])
  func footerStaysInsideItsContainer(
    name: String,
    colorScheme: ColorScheme,
    dynamicTypeSize: DynamicTypeSize,
    bottomInset: Double
  ) throws {
    let clerk = Clerk.mockSignedOut
    clerk.environment?.displayConfig.showDevmodeWarning = true
    let background = colorScheme == .dark ? Color.black : Color.white
    let content = background
      .authFooter()
      .safeAreaPadding(.bottom, bottomInset)
      .environment(clerk)
      .environment(\.clerkFooterHostBottomInset, bottomInset)
      .environment(\.colorScheme, colorScheme)
      .environment(\.dynamicTypeSize, dynamicTypeSize)
      .environment(\.locale, Locale(identifier: "en_US"))
      .frame(width: 393, height: 160)
      .clipped()
      .background(background)
    let renderer = ImageRenderer(content: content)
    renderer.scale = 3
    renderer.isOpaque = true
    let image = try #require(renderer.uiImage)
    let data = try #require(image.pngData())
    Attachment.record(data, named: "\(name)-actual.png")

    let referenceURL = try #require(Bundle.module.url(
      forResource: name,
      withExtension: "png",
      subdirectory: "Snapshots/AuthFooter"
    ))
    let reference = try Data(contentsOf: referenceURL)
    let matches = data == reference
    if !matches {
      Attachment.record(reference, named: "\(name)-expected.png")
    }
    #expect(matches, "Auth footer snapshot changed: \(name). Review the attached actual and expected images.")
  }
}

#endif
