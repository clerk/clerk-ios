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
  ) -> Bool {
    guard let presenter = topViewController() else { return false }

    presenter.present(
      ReverificationHostingController(clerk: clerk, request: request, onDismiss: onDismiss),
      animated: true
    )
    return true
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive }
      ?? scenes.first { $0.activationState == .foregroundInactive }
    let windows = scene?.windows.filter { !$0.isHidden && $0.windowLevel == .normal } ?? []
    guard var top = (windows.first(where: \.isKeyWindow) ?? windows.last)?.rootViewController else {
      return nil
    }
    while let presented = top.presentedViewController, !presented.isBeingDismissed {
      top = presented
    }
    return top
  }
}

private final class ReverificationHostingController: UIHostingController<PresentedReverificationView> {
  private var onDismiss: (@MainActor () -> Void)?

  init(clerk: Clerk, request: ReverificationRequest, onDismiss: @escaping @MainActor () -> Void) {
    self.onDismiss = onDismiss
    super.init(rootView: PresentedReverificationView(clerk: clerk, request: request, dismiss: {}))
    rootView = PresentedReverificationView(clerk: clerk, request: request) { [weak self] in
      self?.dismiss(animated: true)
    }
  }

  @available(*, unavailable)
  @MainActor dynamic required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    guard isBeingDismissed || presentingViewController == nil || presentingViewController?.isBeingDismissed == true else {
      return
    }
    let onDismiss = onDismiss
    self.onDismiss = nil
    onDismiss?()
  }
}

#endif
