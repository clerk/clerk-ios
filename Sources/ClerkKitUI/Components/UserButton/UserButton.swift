//
//  UserButton.swift
//  Clerk
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

  public enum PresentationContext {
    case standard
    case sessionTaskToolbar
  }

  @State private var presentedSheet: PresentedSheet?
  private let presentationContext: PresentationContext
  private let signedOutContent: () -> SignedOutContent

  private enum PresentedSheet: String, Identifiable {
    case userProfile
    case sessionTaskAuth
    case signOut

    var id: String { rawValue }
  }

  /// Creates a new user button.
  ///
  /// The button will automatically display the current user's profile image
  /// and handle presenting the user profile sheet when tapped.
  public init(
    presentationContext: PresentationContext = .standard,
    @ViewBuilder signedOutContent: @escaping () -> SignedOutContent
  ) {
    self.presentationContext = presentationContext
    self.signedOutContent = signedOutContent
  }

  /// Creates a new user button with no signed-out content.
  public init(presentationContext: PresentationContext = .standard) where SignedOutContent == EmptyView {
    self.presentationContext = presentationContext
    signedOutContent = { EmptyView() }
  }

  private var hasPendingSessionTasks: Bool {
    return clerk.session?.pendingTasks.isEmpty == false
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
        UserProfileView()
          .presentationDragIndicator(.visible)
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

#Preview {
  UserButton()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
