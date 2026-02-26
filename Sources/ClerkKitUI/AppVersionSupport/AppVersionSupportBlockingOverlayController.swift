//
//  AppVersionSupportBlockingOverlayController.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI
import UIKit

@MainActor
final class AppVersionSupportBlockingOverlayController {
  static let shared = AppVersionSupportBlockingOverlayController()

  private var status: Clerk.AppVersionSupportStatus?
  private var theme: ClerkTheme = .default
  private weak var clerk: Clerk?
  private var overlayWindow: UIWindow?
  private weak var previousKeyWindow: UIWindow?
  private var isDismissing = false
  private var presentationRetryObservers: [NSObjectProtocol] = []

  private init() {}

  func clear() {
    status = nil
    cancelPresentationRetry()
    dismissOverlay(animated: true)
  }

  func update(with status: Clerk.AppVersionSupportStatus, theme: ClerkTheme, clerk: Clerk) {
    self.theme = theme
    self.clerk = clerk
    self.status = status.isSupported ? nil : status
    render()
  }

  private func render() {
    guard let status else {
      cancelPresentationRetry()
      dismissOverlay(animated: true)
      return
    }

    guard let windowScene = activeWindowScene() else {
      schedulePresentationRetry()
      return
    }
    cancelPresentationRetry()

    let content =
      AppVersionSupportBlockingView(status: status)
        .environment(clerk ?? Clerk.shared)
        .environment(\.clerkTheme, theme)
        .environment(
          \.openURL,
          OpenURLAction { url in
            UIApplication.shared.open(url)
            return .handled
          }
        )

    let hostingController = UIHostingController(rootView: content)
    hostingController.view.backgroundColor = .clear

    let window: UIWindow
    if let existingWindow = overlayWindow,
       existingWindow.windowScene == windowScene
    {
      window = existingWindow
    } else {
      window = UIWindow(windowScene: windowScene)
      window.windowLevel = .alert + 1
      window.backgroundColor = .clear
      overlayWindow = window
    }

    if previousKeyWindow == nil {
      previousKeyWindow = windowScene.windows.first { $0.isKeyWindow }
    }

    window.rootViewController = hostingController
    presentOverlay(window: window)
  }

  private func presentOverlay(window: UIWindow) {
    isDismissing = false
    window.isHidden = false
    window.makeKey()
  }

  private func dismissOverlay(animated: Bool) {
    guard let window = overlayWindow else {
      return
    }

    guard animated, let view = window.rootViewController?.view else {
      cleanupOverlay(window)
      return
    }

    isDismissing = true
    view.layer.removeAllAnimations()
    view.transform = .identity

    UIView.animate(
      withDuration: 0.18,
      delay: 0,
      options: [.curveEaseIn, .beginFromCurrentState, .allowUserInteraction]
    ) {
      view.alpha = 0
    } completion: { [weak self] _ in
      guard let self, isDismissing else { return }
      cleanupOverlay(window)
      isDismissing = false
    }
  }

  private func cleanupOverlay(_ window: UIWindow) {
    window.rootViewController?.view.alpha = 1
    window.rootViewController?.view.transform = .identity
    window.isHidden = true
    window.rootViewController = nil
    if overlayWindow === window {
      overlayWindow = nil
    }
    previousKeyWindow?.makeKey()
    previousKeyWindow = nil
  }

  private func schedulePresentationRetry() {
    guard presentationRetryObservers.isEmpty else {
      return
    }

    let center = NotificationCenter.default
    let names: [NSNotification.Name] = [
      UIScene.didActivateNotification,
      UIScene.willEnterForegroundNotification,
      UIApplication.didBecomeActiveNotification,
    ]

    presentationRetryObservers = names.map { name in
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        self?.attemptPresentationRetry()
      }
    }
  }

  private func cancelPresentationRetry() {
    let center = NotificationCenter.default
    presentationRetryObservers.forEach { center.removeObserver($0) }
    presentationRetryObservers.removeAll()
  }

  private func attemptPresentationRetry() {
    guard status != nil else {
      cancelPresentationRetry()
      return
    }

    guard activeWindowScene() != nil else {
      return
    }

    cancelPresentationRetry()
    render()
  }

  private func activeWindowScene() -> UIWindowScene? {
    let scenes = UIApplication.shared.connectedScenes
    let windowScenes = scenes.compactMap { $0 as? UIWindowScene }

    if let activeScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) {
      return activeScene
    }

    if let inactiveScene = windowScenes.first(where: { $0.activationState == .foregroundInactive }) {
      return inactiveScene
    }

    return windowScenes.first
  }
}

#endif
