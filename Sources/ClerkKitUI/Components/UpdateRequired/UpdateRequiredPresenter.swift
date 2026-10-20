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
  private var isStarted = false
  private var observationGeneration = 0
  private var windows: [ObjectIdentifier: UIWindow] = [:]
  private var sceneObservers: [NSObjectProtocol] = []

  func start(clerk: Clerk) {
    self.clerk = clerk
    guard !isStarted else {
      update()
      return
    }

    isStarted = true
    observationGeneration += 1
    observeScenes()
    observeStatus(generation: observationGeneration)
  }

  func stop() {
    isStarted = false
    sceneObservers.forEach(NotificationCenter.default.removeObserver)
    sceneObservers = []
    hideAll()
  }

  private func observeStatus(generation: Int) {
    guard isStarted, generation == observationGeneration else { return }
    withObservationTracking {
      update()
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.observeStatus(generation: generation)
      }
    }
  }

  private func observeScenes() {
    let center = NotificationCenter.default
    sceneObservers = [UIScene.didActivateNotification, UIScene.willEnterForegroundNotification].map { name in
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.update()
        }
      }
    }
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
    guard isStarted, let clerk, !clerk.appVersionSupportStatus.isSupported else {
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
    _ = UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    window.makeKeyAndVisible()
    UIView.animate(withDuration: 0.2) {
      window.alpha = 1
    }
    return window
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

private struct PresentedUpdateRequiredView: View {
  @Environment(\.colorScheme) private var colorScheme
  private let appearance = UpdateRequiredAppearance.shared

  var body: some View {
    UpdateRequiredView()
      .environment(\.clerkTheme, appearance.theme)
      .environment(\.clerkAppIcon, appearance.appIcon)
      .environment(\.clerkAppIconMaxHeight, appearance.appIconMaxHeight)
      .environment(\.clerkAppIconView, appearance.appIconView(colorScheme: colorScheme))
  }
}

#endif
