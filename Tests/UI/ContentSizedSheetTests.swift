#if os(iOS)

@testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct ContentSizedSheetTests {
  @Test
  func contentFitsWithoutNavigationOrScrolling() async throws {
    let fixture = ContentSizedSheetFixture(usesContainers: false)
    defer { fixture.close() }
    await fixture.layout()

    #expect(fixture.scrollView == nil)
    let contentHeight = try #require(fixture.state.contentHeight)
    #expect(try abs(fixture.detentHeight() - contentHeight.rounded(.up)) <= 1)
  }

  @Test
  func shortContentUsesItsContentHeightAndActualNavigationBar() async throws {
    let fixture = ContentSizedSheetFixture()
    defer { fixture.close() }
    await fixture.layout()

    let contentHeight = try #require(fixture.state.contentHeight)
    let detentHeight = try fixture.detentHeight()
    #expect(detentHeight > contentHeight)
    #expect(detentHeight < fixture.size.height)

    // Let UIKit update its bar for the fitted presentation, then ensure the
    // measured height settles instead of growing on each layout pass.
    fixture.size.height = detentHeight
    await fixture.layout()
    let compactHeight = try fixture.detentHeight()
    fixture.size.height = compactHeight
    await fixture.layout()
    #expect(try abs(fixture.detentHeight() - compactHeight) <= 1)

    fixture.state.showsNavigationBar = false
    await fixture.layout()
    let contentWithoutNavigationBar = try #require(fixture.state.contentHeight)
    let detentWithoutNavigationBar = try fixture.detentHeight()
    #expect(abs(detentWithoutNavigationBar - contentWithoutNavigationBar) <= 1,
            "Hidden-bar detent: \(detentWithoutNavigationBar), current content: \(contentWithoutNavigationBar), previous content: \(contentHeight)")
  }

  @Test
  func bottomAttachedPresentationExcludesItsBottomInset() async throws {
    let fixture = ContentSizedSheetFixture(bottomAligned: true)
    defer { fixture.close() }
    await fixture.layout()

    let presentation = try #require(fixture.parent.presentedViewController)
    // The package runner does not have a scene-backed sheet presentation. Supply a
    // known UIKit safe area rather than relying on its simulated home indicator.
    presentation.additionalSafeAreaInsets.bottom = 34
    await fixture.layout()
    let bottomInset = presentation.view.safeAreaInsets.bottom
    try #require(bottomInset >= 34)
    let contentHeight = try #require(fixture.state.contentHeight)
    let scrollView = try #require(fixture.scrollView)
    let nativeViewportHeight = scrollView.bounds.height - scrollView.adjustedContentInset.top - scrollView.adjustedContentInset.bottom
    let nativeChromeHeight = presentation.view.safeAreaLayoutGuide.layoutFrame.height - nativeViewportHeight
    #expect(nativeChromeHeight > 0)

    // Check the SwiftUI measurement against UIKit's actual viewport, independently of
    // the modifier. The custom detent must not include the bottom inset.
    let expectedHeight = (contentHeight + nativeChromeHeight).rounded(.up)
    let detentHeight = try fixture.detentHeight()
    #expect(abs(detentHeight - expectedHeight) <= 1,
            "Detent: \(detentHeight), expected: \(expectedHeight), content: \(contentHeight), chrome: \(nativeChromeHeight), presentation: \(presentation.view.bounds), safe area: \(presentation.view.safeAreaLayoutGuide.layoutFrame), scroll: \(scrollView.bounds), scroll insets: \(scrollView.adjustedContentInset)")

    // UIKit adds the bottom safe area to a custom detent's physical presentation height.
    fixture.size.height = detentHeight + bottomInset
    await fixture.layout()
    #expect(presentation.view.safeAreaInsets.bottom == bottomInset)
    #expect(try abs(fixture.detentHeight() - detentHeight) <= 1)
  }

  @Test
  func contentChangesRefitWithoutChangingTheViewport() async throws {
    let fixture = ContentSizedSheetFixture()
    defer { fixture.close() }
    await fixture.layout()
    let initialHeight = try fixture.detentHeight()
    let initialContentHeight = try #require(fixture.state.contentHeight)

    fixture.state.rowCount = 3
    await fixture.layout()
    let grownHeight = try fixture.detentHeight()
    #expect(grownHeight > initialHeight)

    fixture.state.rowCount = 1
    await fixture.layout()
    let finalHeight = try fixture.detentHeight()
    #expect(finalHeight < grownHeight)
    #expect(try abs(#require(fixture.state.contentHeight) - initialContentHeight) <= 1)
    // Native navigation chrome can settle to a different height after layout.
    // Check its current height rather than assuming it remains unchanged.
    #expect(try abs(finalHeight - fixture.expectedDetentHeight()) <= 1)
  }

  @Test
  func dynamicTypeRefitsContent() async throws {
    let fixture = ContentSizedSheetFixture()
    defer { fixture.close() }
    await fixture.layout()
    let initialHeight = try fixture.detentHeight()
    fixture.state.dynamicTypeSize = .accessibility3
    await fixture.layout()
    #expect(try fixture.detentHeight() > initialHeight)
  }

  @Test
  func narrowingThePresentationRefitsWrappedContent() async throws {
    let fixture = ContentSizedSheetFixture()
    defer { fixture.close() }
    await fixture.layout()
    let wideHeight = try fixture.detentHeight()

    fixture.size.width = 240
    await fixture.layout()

    #expect(try fixture.detentHeight() > wideHeight)
  }

  @Test
  func longContentRemainsScrollableInAConstrainedPresentation() async throws {
    let fixture = ContentSizedSheetFixture()
    defer { fixture.close() }
    fixture.state.rowCount = 30
    fixture.size.height = 240
    await fixture.layout()

    let scrollView = try #require(fixture.scrollView)
    #expect(scrollView.isScrollEnabled)
    #expect(scrollView.contentSize.height > scrollView.bounds.height)
    #expect(try #require(fixture.state.contentHeight) > fixture.size.height)

    let maximumOffset = scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
    let contentBeforeScrolling = try #require(fixture.state.contentHeight)
    scrollView.setContentOffset(CGPoint(x: 0, y: maximumOffset), animated: false)
    #expect(scrollView.contentOffset.y > 0)
    await fixture.layout()
    let afterScrolling = try fixture.detentHeight()
    #expect(try abs(#require(fixture.state.contentHeight) - contentBeforeScrolling) <= 1)
    #expect(try abs(afterScrolling - fixture.expectedDetentHeight()) <= 1)
  }
}

@MainActor
private final class ContentSizedSheetFixture {
  let state: ContentSizedSheetTestState
  let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 700, height: 900))
  let parent: UIHostingController<ContentSizedSheetPresentationProbe>
  private let bottomAligned: Bool
  var size = CGSize(width: 560, height: 600)

  init(usesContainers: Bool = true, bottomAligned: Bool = false) {
    state = ContentSizedSheetTestState()
    state.usesContainers = usesContainers
    self.bottomAligned = bottomAligned
    parent = UIHostingController(rootView: ContentSizedSheetPresentationProbe(state: state))
    window.rootViewController = parent
    window.isHidden = false
  }

  var scrollView: UIScrollView? {
    func find(in view: UIView) -> UIScrollView? {
      if let scrollView = view as? UIScrollView { return scrollView }
      return view.subviews.lazy.compactMap { find(in: $0) }.first
    }
    return parent.presentedViewController.map { find(in: $0.view) } ?? nil
  }

  func detentHeight() throws -> CGFloat {
    let presentation = try #require(parent.presentedViewController)
    let sheet = try #require(presentation.sheetPresentationController)
    let detent = try #require(sheet.detents.first)
    #expect(sheet.detents.count == 1)
    #expect(detent.identifier != .large)
    #expect(detent.identifier != .medium)
    return try #require(detent.resolvedValue(in: ContentSizedSheetResolutionContext()))
  }

  func expectedDetentHeight() throws -> CGFloat {
    let presentation = try #require(parent.presentedViewController)
    let scrollView = try #require(scrollView)
    let viewportHeight = scrollView.bounds.height - scrollView.adjustedContentInset.top - scrollView.adjustedContentInset.bottom
    let chromeHeight = presentation.view.safeAreaLayoutGuide.layoutFrame.height - viewportHeight
    return try (#require(state.contentHeight) + chromeHeight).rounded(.up)
  }

  func layout() async {
    for _ in 0 ..< 6 {
      window.setNeedsLayout()
      window.layoutIfNeeded()
      parent.view.layoutIfNeeded()
      if let presentation = parent.presentedViewController {
        // The package runner has no window scene to attach presentations automatically.
        if presentation.view.superview !== window {
          window.addSubview(presentation.view)
        }
        let origin = CGPoint(x: 40, y: bottomAligned ? window.bounds.maxY - size.height : 80)
        presentation.view.frame = CGRect(origin: origin, size: size)
        presentation.view.setNeedsLayout()
        presentation.view.layoutIfNeeded()
      }
      await withCheckedContinuation { continuation in
        DispatchQueue.main.async { continuation.resume() }
      }
    }
  }

  func close() {
    parent.presentedViewController?.view.removeFromSuperview()
    window.isHidden = true
    window.rootViewController = nil
  }
}

@MainActor
@Observable
private final class ContentSizedSheetTestState {
  var usesContainers = true
  var isPresented = true
  var showsNavigationBar = true
  var rowCount = 1
  var dynamicTypeSize = DynamicTypeSize.large
  var contentHeight: CGFloat?
}

private struct ContentSizedSheetPresentationProbe: View {
  @Bindable var state: ContentSizedSheetTestState

  var body: some View {
    Color.clear
      .sheet(isPresented: $state.isPresented) {
        ContentSizedSheetProbe(state: state)
      }
      .transaction { $0.disablesAnimations = true }
  }
}

private struct ContentSizedSheetProbe: View {
  let state: ContentSizedSheetTestState
  @State private var navigationInset: CGFloat?

  var body: some View {
    if state.usesContainers {
      NavigationStack {
        VStack(spacing: 0) {
          ScrollView {
            ContentSizedSheetTestContent(state: state)
              .contentSizedSheet(additionalHeight: navigationInset)
          }
          .scrollBounceBehavior(.basedOnSize)
          .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: {
            navigationInset = $0
          }
        }
        .environment(\.dynamicTypeSize, state.dynamicTypeSize)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(state.showsNavigationBar ? .visible : .hidden, for: .navigationBar)
      }
    } else {
      ContentSizedSheetTestContent(state: state)
        .contentSizedSheet()
    }
  }
}

private struct ContentSizedSheetTestContent: View {
  let state: ContentSizedSheetTestState

  var body: some View {
    VStack(spacing: 16) {
      ForEach(0 ..< state.rowCount, id: \.self) { _ in
        Text("Choose how you would like to receive your two-step verification code. Link another login option to your account.")
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(24)
    .fixedSize(horizontal: false, vertical: true)
    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
      state.contentHeight = $0
    }
  }
}

@MainActor
private final class ContentSizedSheetResolutionContext: NSObject, UISheetPresentationControllerDetentResolutionContext {
  let containerTraitCollection = UITraitCollection(verticalSizeClass: .regular)
  let maximumDetentValue: CGFloat = 2000
}

#endif
