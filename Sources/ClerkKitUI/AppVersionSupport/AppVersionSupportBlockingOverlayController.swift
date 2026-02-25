//
//  AppVersionSupportBlockingOverlayController.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import Foundation
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

  private init() {}

  func update(with status: Clerk.AppVersionSupportStatus, theme: ClerkTheme, clerk: Clerk) {
    self.theme = theme
    self.clerk = clerk
    self.status = status.isSupported ? nil : status
    render()
  }

  private func render() {
    guard let status else {
      dismissOverlay(animated: true)
      return
    }

    guard let windowScene = activeWindowScene() else {
      return
    }

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
    presentOverlay(window: window, animated: true)
  }

  private func presentOverlay(window: UIWindow, animated: Bool) {
    isDismissing = false
    window.isHidden = false
    window.makeKey()

    guard animated, let view = window.rootViewController?.view else {
      return
    }

    view.layer.removeAllAnimations()
    view.transform = .identity
    view.alpha = 0

    UIView.animate(
      withDuration: 0.22,
      delay: 0,
      options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
    ) {
      view.alpha = 1
    }
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

  private func activeWindowScene() -> UIWindowScene? {
    let scenes = UIApplication.shared.connectedScenes
    let windowScenes = scenes.compactMap { $0 as? UIWindowScene }

    if let activeScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) {
      return activeScene
    }

    return windowScenes.first(where: { $0.activationState == .foregroundInactive })
  }
}

#endif
