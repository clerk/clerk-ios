//
//  HomeView.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

struct HomeView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.colorScheme) private var colorScheme

  private var pageBackground: Color {
    switch colorScheme {
    case .dark:
      Color(uiColor: .secondarySystemBackground)
    default:
      Color(uiColor: .systemBackground)
    }
  }

  private var displayName: String {
    let firstName = clerk.user?.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return firstName.isEmpty ? "Guest" : firstName
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        ProfileHeaderView()
          .padding(.top, 24)

        ProfileCardView(
          displayName: displayName,
          imageUrl: clerk.user?.imageUrl
        )

        LogoutRowView {
          signOut()
        }
        .padding(.bottom, 32)
      }
      .padding(.horizontal, 24)
    }
    .background(pageBackground.ignoresSafeArea())
  }

  private func signOut() {
    Task {
      do {
        try await clerk.auth.signOut()
      } catch {
        print("Sign out error: \(error.localizedDescription)")
      }
    }
  }
}

// MARK: - ProfileHeaderView

private struct ProfileHeaderView: View {
  var body: some View {
    HStack(alignment: .center) {
      Text("Profile")
        .font(.system(size: 34, weight: .bold))
        .foregroundStyle(.primary)

      Spacer()

      NotificationButton()
    }
  }
}

// MARK: - NotificationButton

private struct NotificationButton: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button {} label: {
      Image(systemName: "bell")
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(.primary)
        .frame(width: 44, height: 44)
        .background(Color(uiColor: .systemBackground))
        .clipShape(.circle)
        .overlay {
          if colorScheme == .dark {
            Circle()
              .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
          }
        }
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 8)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - ProfileCardView

private struct ProfileCardView: View {
  let displayName: String
  let imageUrl: String?

  var body: some View {
    HStack(spacing: 20) {
      VStack(spacing: 12) {
        ProfileAvatarView(imageUrl: imageUrl)

        VStack(spacing: 4) {
          Text(displayName)
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(.primary)

          Text("United States")
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .center)

      StatsColumnView()
    }
    .padding(20)
    .airbnbCardSurface(cornerRadius: 28)
  }
}

// MARK: - ProfileAvatarView

private struct ProfileAvatarView: View {
  let imageUrl: String?

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      AvatarImageView(imageUrl: imageUrl)
        .frame(width: 112, height: 112)
        .clipShape(.circle)

      VerifiedBadge()
        .offset(x: 6, y: 6)
    }
  }
}

// MARK: - AvatarImageView

private struct AvatarImageView: View {
  let imageUrl: String?

  var body: some View {
    if let imageUrl, let url = URL(string: imageUrl) {
      AsyncImage(url: url) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        default:
          AvatarPlaceholderView()
        }
      }
    } else {
      AvatarPlaceholderView()
    }
  }
}

// MARK: - VerifiedBadge

private struct VerifiedBadge: View {
  var body: some View {
    Circle()
      .fill(Color(red: 0.87, green: 0.0, blue: 0.35))
      .frame(width: 36, height: 36)
      .overlay {
        Image(systemName: "checkmark.seal.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.white)
      }
  }
}

// MARK: - AvatarPlaceholderView

private struct AvatarPlaceholderView: View {
  var body: some View {
    ZStack {
      Color(uiColor: .systemGray5)
      Image(systemName: "person.fill")
        .font(.system(size: 36))
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - StatsColumnView

private struct StatsColumnView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StatRowView(value: "7", label: "Trips")
      StatSeparator()
      StatRowView(value: "5", label: "Reviews")
      StatSeparator()
      StatRowView(value: "12", label: "Years on Airbnb")
    }
    .frame(width: 140, alignment: .leading)
  }
}

// MARK: - StatRowView

private struct StatRowView: View {
  let value: String
  let label: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(.primary)
      Text(label)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
        .lineLimit(2)
        .frame(height: 34, alignment: .topLeading)
    }
    .frame(height: 62, alignment: .topLeading)
  }
}

// MARK: - StatSeparator

private struct StatSeparator: View {
  var body: some View {
    Rectangle()
      .fill(Color(uiColor: .systemGray5))
      .frame(height: 1)
      .padding(.vertical, 12)
  }
}

// MARK: - LogoutRowView

private struct LogoutRowView: View {
  let action: () -> Void

  var body: some View {
    Button {
      action()
    } label: {
      HStack(spacing: 16) {
        Image(systemName: "rectangle.portrait.and.arrow.right")
          .font(.system(size: 20))
          .foregroundStyle(.primary)
          .frame(width: 24)

        Text("Log out")
          .font(.system(size: 17))
          .foregroundStyle(.primary)

        Spacer()
      }
      .padding(.vertical, 10)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Preview

#Preview {
  HomeView()
    .environment(Clerk.preview())
}
