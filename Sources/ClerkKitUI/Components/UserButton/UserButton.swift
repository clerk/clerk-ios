//
//  UserButton.swift
//  Clerk
//
//  Created by Mike Pitre on 5/1/25.
//

#if os(iOS)

import ClerkKit
import NukeUI
import SwiftUI

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
public struct UserButton<SignedOutContent: View>: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var userProfileIsPresented: Bool = false
  private let treatPendingAsSignedOut: Bool
  private let signedOutContent: () -> SignedOutContent

  private var user: User? {
    clerk.resolvedUser(treatPendingAsSignedOut: treatPendingAsSignedOut)
  }

  /// Creates a new user button.
  ///
  /// The button will automatically display the current user's profile image
  /// and handle presenting the user profile sheet when tapped.
  public init(
    treatPendingAsSignedOut: Bool = true,
    @ViewBuilder signedOutContent: @escaping () -> SignedOutContent
  ) {
    self.treatPendingAsSignedOut = treatPendingAsSignedOut
    self.signedOutContent = signedOutContent
  }

  /// Creates a new user button with no signed-out content.
  public init(treatPendingAsSignedOut: Bool = true) where SignedOutContent == EmptyView {
    self.treatPendingAsSignedOut = treatPendingAsSignedOut
    signedOutContent = { EmptyView() }
  }

  public var body: some View {
    ZStack {
      if let user {
        Button {
          userProfileIsPresented = true
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
      } else {
        signedOutContent()
      }
    }
    .sheet(isPresented: $userProfileIsPresented) {
      UserProfileView(treatPendingAsSignedOut: treatPendingAsSignedOut)
        .presentationDragIndicator(.visible)
    }
    .onChange(of: user) { _, newValue in
      if newValue == nil {
        userProfileIsPresented = false
      }
    }
    .taskOnce {
      await clerk.telemetry.record(TelemetryEvents.viewDidAppear("UserButton"))
    }
  }
}

#Preview {
  UserButton()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
