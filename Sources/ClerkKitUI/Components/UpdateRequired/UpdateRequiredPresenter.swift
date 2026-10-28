//
//  UpdateRequiredPresenter.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI
import UIKit

@objc(ClerkKitUIAutomaticPresenter)
@MainActor
final class UpdateRequiredPresenter: NSObject, ClerkAutomaticPresenter {
  private weak var clerk: Clerk?
  private lazy var loop = UpdateRequiredPresentationLoop { [weak self] in
    self?.update()
  }

  private var windows: [ObjectIdentifier: UIWindow] = [:]
  private var sceneObservers: [NSObjectProtocol] = []

  func start(clerk: Clerk) {
    self.clerk = clerk
    guard !loop.isStarted else {
      update()
      return
    }

    observeScenes()
    loop.start()
  }

  func stop() {
    loop.stop()
    sceneObservers.forEach(NotificationCenter.default.removeObserver)
    sceneObservers = []
    hideAll()
  }

  private func observeScenes() {
    let center = NotificationCenter.default
    sceneObservers = [UIScene.didActivateNotification, UIScene.willEnterForegroundNotification].map { name in
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.loop.scheduleUpdate()
        }
      }
    }
    // A field the app focuses after the update screen appears, such as after showing
    // the rejected request's error, brings the keyboard back over this window and
    // sends typing to the hidden field.
    sceneObservers.append(
      center.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.endEditingInAppWindows()
        }
      }
    )
    sceneObservers.append(
      center.addObserver(forName: UIScene.didDisconnectNotification, object: nil, queue: .main) { [weak self] notification in
        guard let scene = notification.object as? UIScene else { return }
        let sceneID = ObjectIdentifier(scene)
        MainActor.assumeIsolated {
          self?.windows[sceneID]?.isHidden = true
          self?.windows[sceneID] = nil
        }
      }
    )
  }

  private func update() {
    guard loop.isStarted, let clerk, !clerk.appVersionSupportStatus.isSupported else {
      hideAll()
      return
    }

    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for scene in scenes where windows[ObjectIdentifier(scene)] == nil {
      windows[ObjectIdentifier(scene)] = show(on: scene, clerk: clerk)
    }
  }

  private func show(on scene: UIWindowScene, clerk: Clerk) -> UIWindow {
    let hostingController = UIHostingController(rootView: PresentedUpdateRequiredView().environment(clerk))
    hostingController.view.accessibilityViewIsModal = true

    let window = UIWindow(windowScene: scene)
    window.windowLevel = .alert + 1
    window.rootViewController = hostingController
    window.alpha = 0
    // Close the keyboard first, or it stays above this window and typing goes to
    // the hidden field.
    dismissKeyboard()
    window.makeKeyAndVisible()
    UIView.animate(withDuration: 0.2) {
      window.alpha = 1
    }
    return window
  }

  private func endEditingInAppWindows() {
    guard !windows.isEmpty else { return }
    let presented = Set(windows.values.map(ObjectIdentifier.init))
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for window in scenes.flatMap(\.windows) where !presented.contains(ObjectIdentifier(window)) {
      window.endEditing(true)
    }
  }

  private func hideAll() {
    guard !windows.isEmpty else { return }

    let hiddenWindows = Array(windows.values)
    windows = [:]
    for window in hiddenWindows {
      UIView.animate(withDuration: 0.2) {
        window.alpha = 0
      } completion: { _ in
        let wasKey = window.isKeyWindow
        window.isHidden = true
        window.rootViewController = nil
        if wasKey {
          window.windowScene?.windows.last { !$0.isHidden && $0.windowLevel == .normal }?.makeKey()
        }
      }
    }
  }
}

#endif
