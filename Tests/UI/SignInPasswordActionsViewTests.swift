#if os(iOS)

@testable import ClerkKitUI
import SwiftUI
import Testing

@MainActor
struct SignInPasswordActionsViewTests {
  @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
  func wideRowMatchesExistingAppearance(direction: LayoutDirection) throws {
    let original = try render(legacySpacing: 16, width: 390, direction: direction)
    let adaptive = try render(width: 390, direction: direction)

    #expect(adaptive.pngData() == original.pngData())
  }

  @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
  func narrowRowFitsOnOneLine(direction: LayoutDirection) throws {
    let original = try render(legacySpacing: 16, width: 340, direction: direction)
    let adaptive = try render(width: 340, direction: direction)
    let compact = try render(legacySpacing: 8, width: 340, direction: direction)
    let wide = try render(legacySpacing: 16, width: 390, direction: direction)

    #expect(adaptive.size.height < original.size.height)
    #expect(adaptive.size.height == wide.size.height)
    #expect(adaptive.pngData() == compact.pngData())
  }

  @Test
  func accessibilityTextStillWrapsWithoutClipping() throws {
    let adaptive = try render(width: 340, dynamicTypeSize: .accessibility3)
    let compact = try render(legacySpacing: 8, width: 340, dynamicTypeSize: .accessibility3)
    let standard = try render(width: 340)

    #expect(adaptive.size.height > standard.size.height)
    #expect(adaptive.pngData() == compact.pngData())
  }

  @Test
  func singleActionRendersAtTheHeightOfThePair() throws {
    let pair = try render(width: 390)
    let forgotPasswordOnly = try render(width: 390, includesUseAnotherMethod: false)

    #expect(forgotPasswordOnly.size.height == pair.size.height)
    #expect(forgotPasswordOnly.pngData() != pair.pngData())
  }

  private func render(
    legacySpacing: CGFloat? = nil,
    width: CGFloat,
    direction: LayoutDirection = .leftToRight,
    dynamicTypeSize: DynamicTypeSize = .large,
    includesUseAnotherMethod: Bool = true
  ) throws -> UIImage {
    let renderer = ImageRenderer(content: PasswordActionsViewFixture(legacySpacing: legacySpacing, includesUseAnotherMethod: includesUseAnotherMethod)
      .environment(\.locale, Locale(identifier: "en"))
      .environment(\.layoutDirection, direction)
      .environment(\.dynamicTypeSize, dynamicTypeSize))
    renderer.proposedSize = ProposedViewSize(width: width, height: nil)
    renderer.scale = 2
    return try #require(renderer.uiImage)
  }
}

private struct PasswordActionsViewFixture: View {
  @Environment(\.clerkTheme) private var theme
  let legacySpacing: CGFloat?
  let includesUseAnotherMethod: Bool

  var body: some View {
    if let legacySpacing {
      HStack(spacing: legacySpacing) {
        Button {} label: {
          Text("Use another method")
            .frame(maxWidth: .infinity)
        }

        Rectangle()
          .foregroundStyle(theme.colors.border)
          .frame(width: 1, height: 16)

        Button {} label: {
          Text("Forgot password?")
            .frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.primary(config: .init(emphasis: .none, size: .small)))
    } else {
      SignInPasswordActionsView(onUseAnotherMethod: includesUseAnotherMethod ? {} : nil, onForgotPassword: {})
    }
  }
}

#endif
