#if os(iOS)

@testable import ClerkKitUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct ClerkRepeatingAnimationTests {
  @Test(arguments: [ClerkRepeatingAnimationView.Kind.spinner, .cursor(isOn: true)])
  func animationRestartsWhenTheViewReturnsToAWindow(kind: ClerkRepeatingAnimationView.Kind) async throws {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let controller = UIViewController()
    window.rootViewController = controller
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    let view = ClerkRepeatingAnimationView(kind: kind)
    view.frame = CGRect(x: 20, y: 20, width: 24, height: 24)
    controller.view.addSubview(view)
    #expect(view.layer.animationKeys()?.count == 1)
    #expect(!view.isUserInteractionEnabled)
    #expect(!view.isAccessibilityElement)

    view.removeFromSuperview()
    #expect(view.layer.animationKeys()?.isEmpty != false)
    controller.view.addSubview(view)
    #expect(view.layer.animationKeys()?.count == 1)

    try await Task.sleep(for: .milliseconds(200))
    let presentation = try #require(view.layer.presentation())
    switch kind {
    case .spinner:
      #expect(!CATransform3DIsIdentity(presentation.transform))
    case .cursor:
      #expect(presentation.opacity > 0 && presentation.opacity < 1)
    }
  }

  @Test
  func returningToTheForegroundRestartsAnAnimationRemovedByTheSystem() {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    window.rootViewController = UIViewController()
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    let view = ClerkRepeatingAnimationView(kind: .spinner)
    window.rootViewController?.view.addSubview(view)
    view.layer.removeAllAnimations()
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    #expect(view.layer.animationKeys()?.count == 1)
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    #expect(view.layer.animationKeys()?.count == 1)
  }
}

#endif
