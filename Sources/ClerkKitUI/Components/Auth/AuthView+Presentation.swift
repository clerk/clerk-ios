//
//  AuthView+Presentation.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI
import UIKit

extension AuthView {
  /// Presentation style used when presenting `AuthView` automatically.
  public enum PresentationStyle: Sendable {
    case sheet
    case fullScreen
  }

  /// Presents `AuthView` from non-UI contexts.
  ///
  /// - Parameters:
  ///   - mode: The authentication mode to display. Defaults to `.signInOrUp`.
  ///   - presentationStyle: Sheet or full-screen presentation.
  ///   - theme: Optional theme override for the presented view. When `nil`, the default theme is used.
  public static func present(
    mode: Mode = .signInOrUp,
    presentationStyle: PresentationStyle = .sheet,
    theme: ClerkTheme? = nil
  ) {
    Task { @MainActor in
      AuthViewPresenter.shared.present(
        mode: mode,
        presentationStyle: presentationStyle,
        theme: theme
      )
    }
  }
}

@MainActor
final class AuthViewPresenter {
  static let shared = AuthViewPresenter()
  private weak var presentedController: UIViewController?

  private init() {}

  func present(
    mode: AuthView.Mode,
    presentationStyle: AuthView.PresentationStyle,
    theme: ClerkTheme?
  ) {
    if isAuthViewAlreadyPresented { return }

    guard let presenter = resolveTopViewController() else {
      ClerkLogger.warning("AuthView.present(...) could not find an active key window to present from.")
      return
    }

    var rootView = AnyView(
      AuthView(mode: mode, isDismissable: true)
        .environment(Clerk.shared)
    )

    if let theme {
      rootView = AnyView(rootView.environment(\.clerkTheme, theme))
    }

    let hosting = AuthViewHostingController(rootView: rootView)
    switch presentationStyle {
    case .fullScreen:
      hosting.modalPresentationStyle = .fullScreen
    case .sheet:
      hosting.modalPresentationStyle = .pageSheet
    }
    presenter.present(hosting, animated: true)
    presentedController = hosting
  }

  private var isAuthViewAlreadyPresented: Bool {
    if let presentedController, presentedController.presentingViewController != nil {
      return true
    }
    if let top = resolveTopViewController(), top is AuthViewHostingController {
      return true
    }
    return false
  }

  private func resolveTopViewController() -> UIViewController? {
    guard let root = Self.keyWindow()?.rootViewController else { return nil }
    return Self.topViewController(from: root)
  }

  private static func keyWindow() -> UIWindow? {
    let activeScenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }

    let windows = activeScenes.flatMap(\.windows)
    if let key = windows.first(where: { $0.isKeyWindow }) {
      return key
    }

    let allWindows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)

    return allWindows.first(where: { $0.isKeyWindow })
  }

  private static func topViewController(from root: UIViewController) -> UIViewController {
    if let presented = root.presentedViewController {
      return topViewController(from: presented)
    }
    if let nav = root as? UINavigationController, let visible = nav.visibleViewController {
      return topViewController(from: visible)
    }
    if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
      return topViewController(from: selected)
    }
    return root
  }
}

final class AuthViewHostingController: UIHostingController<AnyView> {}

#endif
