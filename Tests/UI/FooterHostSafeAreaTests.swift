#if os(iOS)

@testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
struct FooterHostSafeAreaTests {
  @Test
  func hostingRootKeepsItsObserverOutsideSwiftUIContent() async throws {
    let recorder = FooterInsetRecorder()
    let host = UIHostingController(rootView: FooterInsetProbe(recorder: recorder))
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = host
    window.isHidden = false
    defer {
      window.isHidden = true
      window.rootViewController = nil
    }
    for _ in 0 ..< 3 {
      window.layoutIfNeeded()
      host.view.layoutIfNeeded()
      await withCheckedContinuation { continuation in
        DispatchQueue.main.async { continuation.resume() }
      }
    }

    let safeArea = try #require(recorder.safeArea)
    #expect(safeArea.hostInset == host.view.safeAreaInsets.bottom)
    #expect(!host.view.subviews.contains { $0 is FooterContainerSafeAreaView })
    let superview = try #require(host.view.superview)
    let observer = try #require(superview.subviews.first { $0 is FooterContainerSafeAreaView })
    #expect(observer.superview === host.view.superview)
    #expect(observer.isUserInteractionEnabled == false)
  }

  @Test(arguments: [false, true])
  func nativeAndEmbeddedFootersDiscoverTheWindowInset(consumesSafeArea: Bool) async throws {
    let fixture = FooterHostingFixture(consumesSafeArea: consumesSafeArea)
    defer { fixture.close() }
    await fixture.layout()

    let windowInset = fixture.window.safeAreaInsets.bottom
    #expect(windowInset > 0)
    let safeArea = try #require(fixture.recorder.safeArea)
    #expect(safeArea.hostInset == windowInset)
    #expect(safeArea.containerInset == (consumesSafeArea ? 0 : windowInset))
    #expect(safeArea.additionalPadding == (consumesSafeArea ? windowInset : 0))
    #expect(safeArea.backgroundSafeAreaEdges.contains(.bottom))
  }

  @Test
  func customContainerPaddingIsNotAddedToTheFooter() async throws {
    let fixture = FooterHostingFixture(consumesSafeArea: true, additionalInset: 50)
    defer { fixture.close() }
    await fixture.layout()

    let windowInset = fixture.window.safeAreaInsets.bottom
    #expect(fixture.parent.view.safeAreaInsets.bottom == windowInset + 50)
    let safeArea = try #require(fixture.recorder.safeArea)
    #expect(safeArea.containerInset == 0)
    #expect(safeArea.hostInset == windowInset)
    #expect(safeArea.additionalPadding == windowInset)
  }

  @Test(arguments: [false, true])
  func tabBarHeightIsNotAddedToTheFooter(consumesSafeArea: Bool) async throws {
    let fixture = FooterHostingFixture(consumesSafeArea: consumesSafeArea, hasTabBar: true)
    defer { fixture.close() }
    await fixture.layout()

    let windowInset = fixture.window.safeAreaInsets.bottom
    #expect(fixture.parent.view.safeAreaInsets.bottom > windowInset)
    let safeArea = try #require(fixture.recorder.safeArea)
    #expect(safeArea.hostInset == windowInset)
    #expect(safeArea.additionalPadding == windowInset)
    #expect(safeArea.backgroundSafeAreaEdges.contains(.bottom) == consumesSafeArea)
  }

  @Test
  func resizingAnEmbeddedHostRefreshesTheObservedInset() async throws {
    let fixture = FooterHostingFixture(consumesSafeArea: true)
    defer { fixture.close() }
    await fixture.layout()
    let originalFrame = fixture.window.frame
    let originalInset = fixture.parent.view.safeAreaInsets.bottom
    #expect(originalInset > 0)
    #expect(try #require(fixture.recorder.safeArea).additionalPadding == originalInset)

    // A scene-less window does not consistently change its safe area when resized.
    // Control that UIKit input while retaining the real observer and layout callbacks.
    fixture.container.reportedBottomInset = 0
    fixture.window.frame.size.width -= 80
    await fixture.layout()
    #expect(fixture.parent.view.safeAreaInsets.bottom == 0)
    #expect(try #require(fixture.recorder.safeArea).hostInset == 0)
    #expect(try #require(fixture.recorder.safeArea).additionalPadding == 0)

    fixture.container.reportedBottomInset = originalInset
    fixture.window.frame = originalFrame
    await fixture.layout()
    #expect(fixture.parent.view.safeAreaInsets.bottom == originalInset)
    #expect(try #require(fixture.recorder.safeArea).hostInset == originalInset)
    #expect(try #require(fixture.recorder.safeArea).additionalPadding == originalInset)
  }

  @Test(arguments: [false, true])
  func asymmetricHorizontalSafeAreasSurviveHostResizing(leadingEdge: Bool) async throws {
    let fixture = FooterHostingFixture(consumesSafeArea: true)
    defer { fixture.close() }
    fixture.host.additionalSafeAreaInsets.left = leadingEdge ? 64 : 0
    fixture.host.additionalSafeAreaInsets.right = leadingEdge ? 0 : 64
    await fixture.layout()

    if leadingEdge {
      #expect(fixture.host.view.safeAreaInsets.left >= 64)
    } else {
      #expect(fixture.host.view.safeAreaInsets.right >= 64)
    }
    let originalInset = fixture.parent.view.safeAreaInsets.bottom
    #expect(originalInset > 0)
    #expect(try #require(fixture.recorder.safeArea).additionalPadding == originalInset)
    try fixture.expectHorizontalSafeAreaIsRespected()
    let originalContentFrame = try #require(fixture.recorder.contentFrame)

    fixture.container.reportedBottomInset = 0
    fixture.window.frame.size.width -= 80
    await fixture.layout()

    #expect(fixture.parent.view.safeAreaInsets.bottom == 0)
    #expect(try #require(fixture.recorder.safeArea).additionalPadding == 0)
    try fixture.expectHorizontalSafeAreaIsRespected()
    #expect(try #require(fixture.recorder.contentFrame).width < originalContentFrame.width)
  }

  @Test
  func removingTheFooterRemovesItsHostObserver() async throws {
    let fixture = FooterHostingFixture(consumesSafeArea: true)
    await fixture.layout()
    let superview = try #require(fixture.parent.view.superview)
    #expect(superview.subviews.contains { $0 is FooterContainerSafeAreaView })

    fixture.close()
    #expect(!superview.subviews.contains { $0 is FooterContainerSafeAreaView })
  }

  @Test
  func visibleFooterWithoutHostTrackingDoesNotInstallAnObserver() async throws {
    let fixture = FooterHostingFixture(consumesSafeArea: true, tracksHostSafeArea: false)
    defer { fixture.close() }
    await fixture.layout()

    let superview = try #require(fixture.parent.view.superview)
    #expect(!superview.subviews.contains { $0 is FooterContainerSafeAreaView })
    let safeArea = try #require(fixture.recorder.safeArea)
    #expect(safeArea.containerInset == 0)
    #expect(safeArea.hostInset == 0)
  }

  @Test
  func separatePresentationDoesNotInheritItsPresentersInsets() async throws {
    let fixture = FooterHostingFixture(consumesSafeArea: true, additionalInset: 50)
    defer { fixture.close() }
    await fixture.layout()

    let recorder = FooterInsetRecorder()
    let sheet = UIHostingController(rootView: FooterInsetProbe(recorder: recorder))
    sheet.modalPresentationStyle = .pageSheet
    fixture.parent.present(sheet, animated: false)
    // The package test runner has no window scene to attach presentations automatically.
    sheet.view.frame = fixture.window.bounds.insetBy(dx: 60, dy: 150)
    fixture.window.addSubview(sheet.view)
    defer { sheet.view.removeFromSuperview() }
    await fixture.layout()
    sheet.view.layoutIfNeeded()
    await fixture.layout()

    #expect(sheet.presentingViewController === fixture.parent)
    #expect(sheet.parent == nil)
    #expect(sheet.view.window === fixture.window)
    #expect(sheet.view.safeAreaInsets.bottom == 0)
    let safeArea = try #require(recorder.safeArea)
    #expect(safeArea.hostInset == 0)
    #expect(safeArea.additionalPadding == 0)
    #expect(safeArea.hostInset < fixture.parent.view.safeAreaInsets.bottom)
  }
}

@MainActor
private final class FooterHostingFixture {
  let recorder = FooterInsetRecorder()
  let parent = UIViewController()
  let container = FooterSafeAreaContainerView()
  let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
  let host: UIViewController

  init(
    consumesSafeArea: Bool,
    additionalInset: CGFloat = 0,
    hasTabBar: Bool = false,
    tracksHostSafeArea: Bool = true
  ) {
    host = UIHostingController(rootView: FooterInsetProbe(
      recorder: recorder,
      tracksHostSafeArea: tracksHostSafeArea
    ))
    parent.view = container
    parent.additionalSafeAreaInsets.bottom = additionalInset
    parent.addChild(host)
    parent.view.addSubview(host.view)
    host.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: parent.view.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor),
      host.view.topAnchor.constraint(equalTo: parent.view.topAnchor),
      host.view.bottomAnchor.constraint(equalTo: consumesSafeArea
        ? parent.view.safeAreaLayoutGuide.bottomAnchor : parent.view.bottomAnchor),
    ])
    host.didMove(toParent: parent)
    if hasTabBar {
      let tabs = UITabBarController()
      parent.tabBarItem = UITabBarItem(title: "Account", image: nil, tag: 0)
      tabs.viewControllers = [parent]
      window.rootViewController = tabs
    } else {
      window.rootViewController = parent
    }
    window.isHidden = false
  }

  func layout() async {
    for _ in 0 ..< 3 {
      window.setNeedsLayout()
      window.layoutIfNeeded()
      window.rootViewController?.view.layoutIfNeeded()
      parent.view.layoutIfNeeded()
      host.view.layoutIfNeeded()
      await withCheckedContinuation { continuation in
        DispatchQueue.main.async { continuation.resume() }
      }
    }
  }

  func close() {
    window.isHidden = true
    window.rootViewController = nil
  }

  func expectHorizontalSafeAreaIsRespected() throws {
    let safeFrame = host.view.safeAreaLayoutGuide.layoutFrame
    let contentFrame = try #require(recorder.contentFrame)
    let footerFrame = try #require(recorder.footerFrame)
    #expect(abs(contentFrame.minX - safeFrame.minX) < 0.5)
    #expect(abs(contentFrame.maxX - safeFrame.maxX) < 0.5)
    #expect(abs(footerFrame.minX - safeFrame.minX) < 0.5)
    #expect(abs(footerFrame.maxX - safeFrame.maxX) < 0.5)
  }
}

@MainActor
private final class FooterSafeAreaContainerView: UIView {
  var reportedBottomInset: CGFloat? {
    didSet {
      safeAreaInsetsDidChange()
      setNeedsLayout()
    }
  }

  override var safeAreaInsets: UIEdgeInsets {
    var insets = super.safeAreaInsets
    if let reportedBottomInset {
      insets.bottom = reportedBottomInset
    }
    return insets
  }
}

@MainActor
private final class FooterInsetRecorder {
  var safeArea: FooterSafeArea?
  var contentFrame: CGRect?
  var footerFrame: CGRect?
}

private struct FooterInsetProbe: View {
  let recorder: FooterInsetRecorder
  var tracksHostSafeArea = true

  var body: some View {
    Color.clear
      .onGeometryChange(for: CGRect.self) { geometry in
        geometry.frame(in: .global)
      } action: { frame in
        recorder.contentFrame = frame
      }
      .bottomTrackedFooter(
        isPresented: true,
        tracksHostSafeArea: tracksHostSafeArea
      ) { safeArea in
        Color.clear.frame(height: 16)
          .padding(.bottom, safeArea.additionalPadding)
          .onGeometryChange(for: CGRect.self) { geometry in
            geometry.frame(in: .global)
          } action: { frame in
            recorder.footerFrame = frame
          }
          .onChange(of: [safeArea.containerInset, safeArea.hostInset], initial: true) {
            recorder.safeArea = safeArea
          }
      }
      .environment(\.layoutDirection, .leftToRight)
  }
}

#endif
