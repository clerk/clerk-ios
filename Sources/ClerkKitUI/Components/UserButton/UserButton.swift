//
//  UserButton.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import NukeUI
import SwiftUI

enum UserButtonPresentationContext {
  case standard
  case sessionTaskToolbar
}

/// A circular button that displays the current user's profile image and opens the user profile when tapped.
///
/// `UserButton` automatically displays the signed-in user's profile image in a circular button.
/// When tapped, it presents a sheet with the full user profile view. You can provide signed-out content
/// that renders when no user is available.
///
/// ## Usage
///
/// Basic usage with authentication state handling:
///
/// ```swift
/// struct HomeView: View {
///   @State private var authIsPresented = false
///
///   var body: some View {
///     ZStack {
///       UserButton(signedOutContent: {
///         Button("Sign in") {
///           authIsPresented = true
///         }
///       })
///     }
///     .sheet(isPresented: $authIsPresented) {
///       AuthView()
///     }
///   }
/// }
/// ```
///
/// In a navigation toolbar:
///
/// ```swift
/// .toolbar {
///   ToolbarItem(placement: .navigationBarTrailing) {
///     UserButton(signedOutContent: {
///       Button("Sign in") {
///         authIsPresented = true
///       }
///     })
///   }
/// }
/// ```
public struct UserButton<Route: Hashable, SignedOutContent: View, Destination: View>: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var presentedSheet: PresentedSheet?
  private let presentationContext: UserButtonPresentationContext
  private let customItems: [UserProfileCustomItem<Route>]
  private let customDestination: (@MainActor (Route) -> Destination)?
  private let signedOutContent: () -> SignedOutContent

  private enum PresentedSheet: String, Identifiable {
    case userProfile
    case sessionTaskAuth
    case signOut

    var id: String {
      rawValue
    }
  }

  /// Creates a new user button.
  ///
  /// The button will automatically display the current user's profile image
  /// and handle presenting the user profile sheet when tapped.
  public init(
    @ViewBuilder signedOutContent: @escaping () -> SignedOutContent
  ) where Route == Never, Destination == EmptyView {
    self.init(
      presentationContext: .standard,
      customItems: [],
      customDestination: nil,
      signedOutContent: signedOutContent
    )
  }

  init(
    presentationContext: UserButtonPresentationContext,
    customItems: [UserProfileCustomItem<Route>],
    customDestination: (@MainActor (Route) -> Destination)?,
    @ViewBuilder signedOutContent: @escaping () -> SignedOutContent
  ) {
    self.presentationContext = presentationContext
    self.customItems = customItems
    self.customDestination = customDestination
    self.signedOutContent = signedOutContent
  }

  /// Creates a new user button with no signed-out content.
  public init() where Route == Never, SignedOutContent == EmptyView, Destination == EmptyView {
    self.init(presentationContext: .standard)
  }

  init(
    presentationContext: UserButtonPresentationContext
  ) where Route == Never, SignedOutContent == EmptyView, Destination == EmptyView {
    self.init(
      presentationContext: presentationContext,
      customItems: [],
      customDestination: nil,
      signedOutContent: { EmptyView() }
    )
  }

  private var hasPendingSessionTasks: Bool {
    clerk.session?.pendingTasks.isEmpty == false
  }

  public var body: some View {
    ZStack {
      if let user = clerk.user {
        Button {
          handleTap()
        } label: {
          LazyImage(url: URL(string: user.imageUrl)) { state in
            if let image = state.image {
              image
                .resizable()
                .scaledToFill()
            } else {
              Image("icon-profile", bundle: .module)
                .resizable()
                .scaledToFit()
                .foregroundStyle(theme.colors.primary.gradient)
                .opacity(0.5)
            }
          }
          .frame(width: 36, height: 36)
          .clipShape(.circle)
          .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        }
        .buttonStyle(.plain)
      } else {
        signedOutContent()
      }
    }
    .sheet(item: $presentedSheet) { sheet in
      switch sheet {
      case .userProfile:
        userProfileSheet
      case .sessionTaskAuth:
        AuthView()
          .presentationDragIndicator(.visible)
      case .signOut:
        UserButtonSignOutView()
          .contentSizingDetent()
      }
    }
    .onChange(of: clerk.user) { _, newValue in
      guard newValue == nil else { return }
      guard presentedSheet != .sessionTaskAuth else { return }
      presentedSheet = nil
    }
    .taskOnce {
      await clerk.telemetry.record(TelemetryEvents.viewDidAppear("UserButton"))
    }
  }
}

extension UserButton {
  /// Replaces the custom items shown in the presented user profile.
  public func userProfileItems(
    _ items: [UserProfileCustomItem<Route>]
  ) -> UserButton<Route, SignedOutContent, Destination> {
    UserButton<Route, SignedOutContent, Destination>(
      presentationContext: presentationContext,
      customItems: items,
      customDestination: customDestination,
      signedOutContent: signedOutContent
    )
  }

  private var userProfileSheet: some View {
    UserProfileView(
      isDismissable: true,
      navigationPath: nil,
      customItems: customItems,
      customDestination: customDestination
    )
    .presentationDragIndicator(.visible)
  }

  private func handleTap() {
    switch presentationContext {
    case .sessionTaskToolbar:
      presentedSheet = .signOut
    case .standard:
      if hasPendingSessionTasks {
        presentedSheet = .sessionTaskAuth
      } else {
        presentedSheet = .userProfile
      }
    }
  }
}

extension UserButton where Destination == EmptyView {
  /// Sets the custom destination builder used by custom items in the presented user profile.
  public func userProfileDestination<NewDestination: View>(
    @ViewBuilder _ destination: @escaping @MainActor (Route) -> NewDestination
  ) -> UserButton<Route, SignedOutContent, NewDestination> {
    UserButton<Route, SignedOutContent, NewDestination>(
      presentationContext: presentationContext,
      customItems: customItems,
      customDestination: destination,
      signedOutContent: signedOutContent
    )
  }
}

extension UserButton where Route == Never, Destination == EmptyView {
  /// Sets the custom items shown in the presented user profile.
  public func userProfileItems<NewRoute: Hashable>(
    _ items: [UserProfileCustomItem<NewRoute>]
  ) -> UserButton<NewRoute, SignedOutContent, EmptyView> {
    UserButton<NewRoute, SignedOutContent, EmptyView>(
      presentationContext: presentationContext,
      customItems: items,
      customDestination: nil,
      signedOutContent: signedOutContent
    )
  }

  /// Sets the custom destination builder used by custom items in the presented user profile.
  public func userProfileDestination<NewRoute: Hashable, NewDestination: View>(
    for _: NewRoute.Type = NewRoute.self,
    @ViewBuilder _ destination: @escaping @MainActor (NewRoute) -> NewDestination
  ) -> UserButton<NewRoute, SignedOutContent, NewDestination> {
    UserButton<NewRoute, SignedOutContent, NewDestination>(
      presentationContext: presentationContext,
      customItems: [],
      customDestination: destination,
      signedOutContent: signedOutContent
    )
  }
}

#Preview {
  UserButton()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
