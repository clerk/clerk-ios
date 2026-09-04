#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import SwiftUI
import Testing

@MainActor
struct FooterEmbeddingSnapshotTests {
  @Test(arguments: [
    ("AuthFooter/bottom-safe-area", true, ColorScheme.light, 393.0, 34.0),
    ("NativeFooter/auth-portrait-dark", true, ColorScheme.dark, 393.0, 34.0),
    ("NativeFooter/auth-landscape", true, ColorScheme.light, 852.0, 21.0),
    ("NativeFooter/organization-light", false, ColorScheme.light, 393.0, 34.0),
    ("NativeFooter/organization-dark", false, ColorScheme.dark, 393.0, 34.0),
  ], [0.0, 0.5])
  func consumingTheSafeAreaPreservesTheEntireFooter(
    scenario: (reference: String, isAuth: Bool, colorScheme: ColorScheme, width: Double, hostInset: Double),
    remainingFraction: Double
  ) throws {
    let clerk = Clerk.mock
    clerk.environment?.displayConfig.showDevmodeWarning = true
    clerk.environment?.displayConfig.branded = true
    let background = scenario.colorScheme == .dark ? Color.black : Color.white
    let content = EmbeddedFooterSnapshotContent(isAuth: scenario.isAuth, background: background)
      .safeAreaPadding(.bottom, scenario.hostInset * remainingFraction)
      .environment(clerk)
      .environment(\.clerkFooterHostBottomInset, scenario.hostInset)
      .environment(\.colorScheme, scenario.colorScheme)
      .environment(\.dynamicTypeSize, DynamicTypeSize.large)
      .environment(\.locale, Locale(identifier: "en_US"))
      .frame(width: scenario.width, height: 160)
      .clipped()
      .background(background)
    let renderer = ImageRenderer(content: content)
    renderer.scale = 3
    renderer.isOpaque = true
    let image = try #require(renderer.uiImage)
    let actual = try #require(image.pngData())
    let path = scenario.reference.split(separator: "/")
    let name = String(path[1])
    Attachment.record(actual, named: "\(name)-remaining-\(remainingFraction).png")
    let url = try #require(Bundle.module.url(
      forResource: name,
      withExtension: "png",
      subdirectory: "Snapshots/\(path[0])"
    ))
    let reference = try Data(contentsOf: url)
    if actual != reference {
      Attachment.record(reference, named: "\(name)-native.png")
    }
    #expect(actual == reference, "The embedded footer must retain the native text, pattern, and bottom-line spacing.")
  }
}

private struct EmbeddedFooterSnapshotContent: View {
  let isAuth: Bool
  let background: Color

  var body: some View {
    if isAuth {
      background.authFooter()
    } else {
      background.securedByClerkFooter()
    }
  }
}

#endif
