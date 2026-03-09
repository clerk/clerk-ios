//
//  UserButton+macOS.swift
//  Clerk
//

#if os(macOS)

import ClerkKit
import SwiftUI

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

    var id: String {
      rawValue
    }
  }

  public init(
    presentationContext: PresentationContext = .standard,
    @ViewBuilder signedOutContent: @escaping () -> SignedOutContent
  ) {
    self.presentationContext = presentationContext
    self.signedOutContent = signedOutContent
  }

  public init(presentationContext: PresentationContext = .standard) where SignedOutContent == EmptyView {
    self.presentationContext = presentationContext
    signedOutContent = { EmptyView() }
  }

  private var hasPendingSessionTasks: Bool {
    clerk.session?.tasks?.isEmpty == false
  }

  public var body: some View {
    Group {
      if let user = clerk.user {
        Button {
          handleTap()
        } label: {
          UserButtonAvatarView(imageUrl: user.imageUrl)
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Open account"))
      } else {
        signedOutContent()
      }
    }
    .sheet(item: $presentedSheet) { sheet in
      switch sheet {
      case .userProfile:
        UserProfileView()
      case .sessionTaskAuth:
        AuthView()
      }
    }
    .onChange(of: clerk.user) { _, newValue in
      guard newValue == nil else { return }
      guard presentedSheet != .sessionTaskAuth else { return }
      presentedSheet = nil
    }
  }
}

extension UserButton {
  private func handleTap() {
    switch presentationContext {
    case .sessionTaskToolbar:
      presentedSheet = .userProfile
    case .standard:
      presentedSheet = hasPendingSessionTasks ? .sessionTaskAuth : .userProfile
    }
  }
}

struct UserButtonAvatarView: View {
  @Environment(\.clerkTheme) private var theme

  let imageUrl: String

  var body: some View {
    AsyncImage(url: URL(string: imageUrl)) { phase in
      switch phase {
      case .success(let image):
        image
          .resizable()
          .scaledToFill()
      default:
        Image("icon-profile", bundle: .module)
          .resizable()
          .scaledToFit()
          .foregroundStyle(theme.colors.mutedForeground)
          .padding(6)
      }
    }
    .background(theme.colors.muted, in: Circle())
    .clipShape(.circle)
    .overlay {
      Circle()
        .strokeBorder(theme.colors.border, lineWidth: 1)
    }
  }
}

#Preview("Signed Out") {
  UserButton {
    Text("Sign in")
  }
  .environment(Clerk.preview { preview in
    preview.isSignedIn = false
  })
}

#Preview("Signed In") {
  UserButton()
    .environment(Clerk.preview())
}

#endif
