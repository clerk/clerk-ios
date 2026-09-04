#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import SwiftUI
import Testing

@MainActor
struct NativeFooterSnapshotTests {
  @Test(arguments: [
    ("auth-portrait-dark", ColorScheme.dark, 393.0, 34.0, 34.0),
    ("auth-landscape", ColorScheme.light, 852.0, 21.0, 21.0),
    ("auth-tab-bar", ColorScheme.light, 402.0, 83.0, 34.0),
    ("organization-light", ColorScheme.light, 393.0, 34.0, 34.0),
    ("organization-dark", ColorScheme.dark, 393.0, 34.0, 34.0),
    ("organization-tab-bar", ColorScheme.light, 402.0, 83.0, 34.0),
    ("organization-compact-light", ColorScheme.light, 393.0, 34.0, 34.0),
    ("organization-compact-dark", ColorScheme.dark, 393.0, 34.0, 34.0),
  ])
  func footerMatchesExpectedAppearance(
    name: String,
    colorScheme: ColorScheme,
    width: Double,
    bottomInset: Double,
    hostInset: Double
  ) throws {
    let clerk = Clerk.mock
    clerk.environment?.displayConfig.showDevmodeWarning = true
    clerk.environment?.displayConfig.branded = true
    let background = colorScheme == .dark ? Color.black : Color.white
    let content = NativeFooterSnapshotContent(name: name, background: background)
      .safeAreaPadding(.bottom, bottomInset)
      .environment(clerk)
      .environment(\.clerkFooterHostBottomInset, hostInset)
      .environment(\.colorScheme, colorScheme)
      .environment(\.dynamicTypeSize, DynamicTypeSize.large)
      .environment(\.locale, Locale(identifier: "en_US"))
      .frame(width: width, height: 160)
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
      subdirectory: "Snapshots/NativeFooter"
    ))
    let reference = try Data(contentsOf: referenceURL)
    let matches = data == reference
    if !matches {
      Attachment.record(reference, named: "\(name)-expected.png")
    }
    #expect(matches, "Native footer snapshot changed: \(name). Review the attached actual and expected images.")
  }
}

private struct NativeFooterSnapshotContent: View {
  let name: String
  let background: Color

  var body: some View {
    if name.hasPrefix("auth-") {
      background.authFooter()
    } else if name.hasPrefix("organization-compact-") {
      VStack(spacing: 0) {
        Spacer(minLength: 0)
        SecuredByClerkFooter(showBackground: false)
      }
    } else {
      background.securedByClerkFooter()
    }
  }
}

#endif
