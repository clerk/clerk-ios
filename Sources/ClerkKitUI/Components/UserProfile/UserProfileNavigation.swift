//
//  UserProfileNavigation.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation
import SwiftUI

/// A scoped controller for a host-owned user profile navigation header.
///
/// Use this when embedding `UserProfileView` in a container that owns the visible
/// header. Clerk still owns the profile flow, while the host can observe title and
/// back state and call `pop()`, `popToRoot()`, or `dismiss()` from its own controls.
@MainActor
@Observable
public final class UserProfileNavigationController {
  public private(set) var title: LocalizedStringKey = "Account"
  public private(set) var canGoBack = false
  public private(set) var canDismiss = true
  public private(set) var shouldDismiss = false

  @ObservationIgnored private var popAction: (@MainActor () -> Void)?
  @ObservationIgnored private var popToRootAction: (@MainActor () -> Void)?
  @ObservationIgnored private var dismissAction: (@MainActor () -> Void)?

  public init() {}

  public func pop() {
    popAction?()
  }

  public func popToRoot() {
    popToRootAction?()
  }

  public func dismiss() {
    dismissAction?()
  }

  public func resetDismissRequest() {
    shouldDismiss = false
  }

  func configure(
    pop: @escaping @MainActor () -> Void,
    popToRoot: @escaping @MainActor () -> Void,
    dismiss: @escaping @MainActor () -> Void
  ) {
    popAction = pop
    popToRootAction = popToRoot
    dismissAction = dismiss
  }

  func update(
    title: LocalizedStringKey,
    canGoBack: Bool,
    canDismiss: Bool
  ) {
    self.title = title
    self.canGoBack = canGoBack
    self.canDismiss = canDismiss
  }

  func requestDismiss() {
    shouldDismiss = true
  }
}

/// Manages presentation state for the user profile flow.
///
/// This class handles sheet presentation state for the user profile.
/// It is injected into child views via the environment.
@MainActor
@Observable
final class UserProfileSheetNavigation {
  /// Whether the account switcher sheet is presented.
  var accountSwitcherIsPresented = false

  /// Whether the auth view sheet is presented.
  var authViewIsPresented = false

  /// Whether the MFA type chooser sheet is presented.
  var chooseMfaTypeIsPresented = false

  /// The currently presented MFA add view type.
  var presentedAddMfaType: UserProfileAddMfaView.PresentedView?
}

/// Navigation API for navigating from custom rows to custom destinations inside
/// `UserProfileView`.
///
/// This is available in the environment when `UserProfileView` manages its own
/// `NavigationStack` (i.e., no `navigationPath` is provided). When a parent
/// `navigationPath` is supplied, the parent owns the stack and is responsible for
/// navigation — `UserProfileNavigator` is not injected in that case.
///
/// Custom destination views can read this value using:
///
/// ```swift
/// @Environment(UserProfileNavigator<MyRoute>.self) private var navigation
/// ```
@MainActor
@Observable
public final class UserProfileNavigator<Route: Hashable> {
  private let pushRow: @MainActor (Route, LocalizedStringKey?) -> Void
  private let popToRootAction: @MainActor () -> Void

  init(
    push: @escaping @MainActor (Route, LocalizedStringKey?) -> Void,
    popToRoot: @escaping @MainActor () -> Void
  ) {
    pushRow = push
    popToRootAction = popToRoot
  }

  public func push(_ route: Route) {
    pushRow(route, nil)
  }

  public func push(_ route: Route, title: LocalizedStringKey) {
    pushRow(route, title)
  }

  /// Pops any pushed custom destinations and returns to the root screen of
  /// `UserProfileView`.
  public func popToRoot() {
    popToRootAction()
  }
}

enum UserProfileBuiltInDestination: Hashable {
  case manageAccount
  case security

  var title: LocalizedStringKey {
    switch self {
    case .manageAccount:
      "Manage account"
    case .security:
      "Security"
    }
  }
}

enum UserProfileDismissAction {
  case popToRoot
  case exitUserProfile
}

/// Internal built-in-only adapter for Clerk-owned child views that should not know about
/// the host app's custom `Route` type but still need to trigger profile navigation.
@MainActor
@Observable
final class UserProfileBuiltInRouter {
  private let pushDestination: @MainActor (UserProfileBuiltInDestination) -> Void
  private let dismissAction: @MainActor (UserProfileDismissAction) -> Void

  init(
    push: @escaping @MainActor (UserProfileBuiltInDestination) -> Void,
    dismissAction: @escaping @MainActor (UserProfileDismissAction) -> Void
  ) {
    pushDestination = push
    self.dismissAction = dismissAction
  }

  func push(_ destination: UserProfileBuiltInDestination) {
    pushDestination(destination)
  }

  func dismiss(_ action: UserProfileDismissAction) {
    dismissAction(action)
  }
}

extension EnvironmentValues {
  @Entry var userProfileUsesExternalNavigationHeader = false
  @Entry var userProfileNavigationController: UserProfileNavigationController?
}

private struct UserProfileNavigationTitleModifier: ViewModifier {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.userProfileUsesExternalNavigationHeader) private var usesExternalNavigationHeader
  @Environment(\.userProfileNavigationController) private var navigationController

  let title: LocalizedStringKey

  func body(content: Content) -> some View {
    content
      .onAppear {
        guard usesExternalNavigationHeader else { return }
        navigationController?.update(title: title, canGoBack: true, canDismiss: true)
      }
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        if !usesExternalNavigationHeader {
          ToolbarItem(placement: .principal) {
            Text(title, bundle: .module)
              .font(theme.fonts.headline)
              .fontWeight(.semibold)
              .foregroundStyle(theme.colors.foreground)
          }
        }
      }
      .userProfileNavigationHeaderStyle()
  }
}

extension View {
  func userProfileNavigationTitle(_ title: LocalizedStringKey) -> some View {
    modifier(UserProfileNavigationTitleModifier(title: title))
  }

  func userProfileNavigationHeaderStyle() -> some View {
    modifier(UserProfileNavigationHeaderModifier())
  }
}

private struct UserProfileNavigationHeaderModifier: ViewModifier {
  @Environment(\.userProfileUsesExternalNavigationHeader) private var usesExternalNavigationHeader

  func body(content: Content) -> some View {
    if usesExternalNavigationHeader {
      #if os(iOS)
      content
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
      #else
      content
      #endif
    } else {
      content
    }
  }
}

#endif
