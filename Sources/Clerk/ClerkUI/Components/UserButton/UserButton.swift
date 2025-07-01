//
//  UserButton.swift
//  Clerk
//
//  Created by Mike Pitre on 5/1/25.
//

#if os(iOS)

  import Kingfisher
  import SwiftUI

  /// A circular button that displays the current user's profile image and opens the user profile when tapped.
  ///
  /// `UserButton` automatically displays the signed-in user's profile image in a circular button.
  /// When tapped, it presents a sheet with the full user profile view. The button only appears
  /// when a user is signed in.
  ///
  /// ## Usage
  ///
  /// Basic usage with authentication state handling:
  ///
  /// ```swift
  /// struct HomeView: View {
  ///   @Environment(\.clerk) private var clerk
  ///   @State private var authIsPresented = false
  ///
  ///   var body: some View {
  ///     ZStack {
  ///       Group {
  ///         if clerk.user != nil {
  ///           UserButton()
  ///             .frame(width: 36, height: 36)
  ///         } else {
  ///           Button("Sign in") {
  ///             authIsPresented = true
  ///           }
  ///         }
  ///       }
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
  ///     if clerk.user != nil {
  ///       UserButton()
  ///         .frame(width: 36, height: 36)
  ///     }
  ///   }
  /// }
  /// ```
  public struct UserButton: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme

    @State private var userProfileIsPresented: Bool = false

    /// Creates a new user button.
    ///
    /// The button will automatically display the current user's profile image
    /// and handle presenting the user profile sheet when tapped.
    public init() {}

    public var body: some View {
      ZStack {
        if let user = clerk.user {
          Button {
            userProfileIsPresented = true
          } label: {
            KFImage(URL(string: user.imageUrl))
              .placeholder {
                Image("icon-profile", bundle: .module)
                  .resizable()
                  .scaledToFit()
                  .foregroundStyle(theme.colors.primary.gradient)
                  .opacity(0.5)
              }
              .resizable()
              .fade(duration: 0.2)
              .scaledToFill()
              .clipShape(.circle)
          }
        }
      }
      .sheet(isPresented: $userProfileIsPresented) {
        UserProfileView(isDismissable: true)
          .presentationDragIndicator(.visible)
      }
      .onChange(of: clerk.user) { _, newValue in
        if newValue == nil {
          userProfileIsPresented = false
        }
      }
    }
  }

  #Preview {
    UserButton()
      .frame(width: 36, height: 36)
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
