//
//  ReverificationSheetDisplay+iOS.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI
import UIKit

@MainActor
struct PlatformReverificationSheetDisplay: ReverificationSheetDisplay {
  func show(
    _ request: ReverificationRequest,
    clerk: Clerk,
    onDismiss: @escaping @MainActor () -> Void
  ) async -> Bool {
    guard let presenter = await settledTopViewController() else { return false }
    if Task.isCancelled {
      return false
    }

    presenter.present(
      ReverificationHostingController(clerk: clerk, request: request, onDismiss: onDismiss),
      animated: true
    )
    return true
  }

  /// UIKit can drop a presentation started while the presenter is still being presented, or is
  /// still dismissing what it presented, so this waits for that transition to end first.
  private func settledTopViewController() async -> UIViewController? {
    while let top = topViewController() {
      guard let transition = top.transitionCoordinator ?? top.presentedViewController?.transitionCoordinator else {
        return top
      }
      let ended = await withCheckedContinuation { continuation in
        let resume = OneTimeAction<Bool> { continuation.resume(returning: $0) }
        let isQueued = transition.animate(alongsideTransition: nil) { _ in
          MainActor.assumeIsolated { resume(true) }
        }
        if !isQueued {
          resume(false)
        }
      }
      guard ended else { return top }
    }
    return nil
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = presentingWindow(in: scenes.filter { $0.activationState == .foregroundActive })
      ?? presentingWindow(in: scenes.filter { $0.activationState == .foregroundInactive })
    guard var top = window?.rootViewController else {
      return nil
    }
    while let presented = top.presentedViewController, !presented.isBeingDismissed {
      top = presented
    }
    return top
  }

  private func presentingWindow(in scenes: [UIWindowScene]) -> UIWindow? {
    let windowsByScene = scenes.map { scene in
      scene.windows.filter { !$0.isHidden && $0.windowLevel == .normal && $0.rootViewController != nil }
    }
    return windowsByScene.joined().first(where: \.isKeyWindow)
      ?? windowsByScene.first { !$0.isEmpty }?.last
  }
}

private final class ReverificationHostingController: UIHostingController<PresentedReverificationView> {
  private let finish: OneTimeAction<Void>
  private var sceneObserver: (any NSObjectProtocol)?

  init(clerk: Clerk, request: ReverificationRequest, onDismiss: @escaping @MainActor () -> Void) {
    finish = OneTimeAction { onDismiss() }
    super.init(rootView: PresentedReverificationView(clerk: clerk, request: request, dismiss: {}))
    rootView = PresentedReverificationView(clerk: clerk, request: request) { [weak self] in
      // Dismissing a controller that presents another one dismisses only the one it presents.
      self?.presentingViewController?.dismiss(animated: true)
    }
  }

  @available(*, unavailable)
  @MainActor dynamic required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// A scene that disconnects, such as an iPad window the user closes, takes the sheet with it
  /// without dismissing it.
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard sceneObserver == nil, let scene = view.window?.windowScene else { return }
    sceneObserver = NotificationCenter.default.addObserver(
      forName: UIScene.didDisconnectNotification,
      object: scene,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.end() }
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    guard isBeingDismissed || presentingViewController == nil || presentingViewController?.isBeingDismissed == true else {
      return
    }
    end()
  }

  private func end() {
    if let sceneObserver {
      NotificationCenter.default.removeObserver(sceneObserver)
      self.sceneObserver = nil
    }
    finish(())
  }
}

#endif
