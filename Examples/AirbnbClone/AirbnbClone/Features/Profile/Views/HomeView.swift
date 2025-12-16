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
  @State private var isSigningOut = false

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        header
          .padding(.horizontal, 24)
          .padding(.top, 24)

        profileCard
          .padding(.horizontal, 24)

        logoutRow
          .padding(.horizontal, 24)
          .padding(.bottom, 32)
      }
    }
    .background(Color(uiColor: .systemBackground))
    .overlay {
      if isSigningOut {
        Color.black.opacity(0.2)
          .ignoresSafeArea()
          .overlay {
            ProgressView()
              .scaleEffect(1.5)
              .tint(.white)
          }
      }
    }
  }

  private var header: some View {
    HStack(alignment: .center) {
      Text("Profile")
        .font(.system(size: 34, weight: .bold))
        .foregroundStyle(.primary)

      Spacer()

      Button {
        // Non-functional (matches screenshot affordance)
      } label: {
        Image(systemName: "bell")
          .font(.system(size: 18, weight: .medium))
          .foregroundStyle(.primary)
          .frame(width: 44, height: 44)
          .background(Color(uiColor: .secondarySystemBackground))
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
    }
  }

  private var displayName: String {
    let firstName = clerk.user?.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return firstName.isEmpty ? "Guest" : firstName
  }

  private var profileCard: some View {
    HStack(spacing: 20) {
      VStack(spacing: 12) {
        ZStack(alignment: .bottomTrailing) {
          avatar
            .frame(width: 96, height: 96)
            .clipShape(Circle())

          // Verified badge (non-functional, visual only)
          Circle()
            .fill(Color(red: 0.87, green: 0.0, blue: 0.35))
            .frame(width: 34, height: 34)
            .overlay {
              Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            }
            .offset(x: 6, y: 6)
        }

        VStack(spacing: 4) {
          Text(displayName)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(.primary)

          Text("United States")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: 12)

      statsColumn
    }
    .padding(20)
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .overlay {
      RoundedRectangle(cornerRadius: 24)
        .strokeBorder(Color(uiColor: .systemGray5), lineWidth: 1)
    }
  }

  private var avatar: some View {
    Group {
      if let imageUrl = clerk.user?.imageUrl, let url = URL(string: imageUrl) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
          default:
            avatarPlaceholder
          }
        }
      } else {
        avatarPlaceholder
      }
    }
  }

  private var avatarPlaceholder: some View {
    ZStack {
      Color(uiColor: .systemGray5)
      Image(systemName: "person.fill")
        .font(.system(size: 36))
        .foregroundStyle(.secondary)
    }
  }

  private func statRow(value: String, label: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(.system(size: 28, weight: .bold))
        .foregroundStyle(.primary)
      Text(label)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.primary)
        .multilineTextAlignment(.leading)
        .lineLimit(2) // reserve the same label space for all rows to avoid "staggered" layout
        .frame(height: 44, alignment: .topLeading)
    }
    .frame(height: 76, alignment: .topLeading)
  }

  private var statSeparator: some View {
    Rectangle()
      .fill(Color(uiColor: .systemGray4))
      .frame(height: 1)
      .padding(.vertical, 12)
  }

  private var statsColumn: some View {
    VStack(alignment: .leading, spacing: 0) {
      statRow(value: "7", label: "Trips")
      statSeparator
      statRow(value: "5", label: "Reviews")
      statSeparator
      statRow(value: "11", label: "Years on Airbnb")
    }
    .frame(width: 156, alignment: .leading)
  }

  private func featureTile(title: String, isNew: Bool, systemImage: String) -> some View {
    VStack(spacing: 14) {
      ZStack(alignment: .topTrailing) {
        ZStack {
          RoundedRectangle(cornerRadius: 16)
            .fill(Color(uiColor: .systemGray6))
          Image(systemName: systemImage)
            .font(.system(size: 34, weight: .regular))
            .foregroundStyle(.secondary)
        }
        .frame(height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 16))

        if isNew {
          Text("NEW")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(uiColor: .tertiaryLabel).opacity(0.9))
            .clipShape(Capsule())
            .padding(10)
        }
      }

      Text(title)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.primary)
        .padding(.bottom, 6)
    }
    .frame(maxWidth: .infinity)
    .padding(16)
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .overlay {
      RoundedRectangle(cornerRadius: 24)
        .strokeBorder(Color(uiColor: .systemGray5), lineWidth: 1)
    }
  }

  private func wideTile(title: String, subtitle: String, systemImage: String) -> some View {
    HStack(spacing: 16) {
      ZStack {
        RoundedRectangle(cornerRadius: 14)
          .fill(Color(uiColor: .systemGray6))
          .frame(width: 56, height: 56)
        Image(systemName: systemImage)
          .font(.system(size: 24))
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(.primary)
        Text(subtitle)
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(16)
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .overlay {
      RoundedRectangle(cornerRadius: 24)
        .strokeBorder(Color(uiColor: .systemGray5), lineWidth: 1)
    }
  }

  private var logoutRow: some View {
    Button {
      signOut()
    } label: {
      HStack(spacing: 16) {
        Image(systemName: "rectangle.portrait.and.arrow.right")
          .font(.system(size: 20))
          .foregroundStyle(.primary)
          .frame(width: 24)

        Text("Log out")
          .font(.system(size: 18))
          .foregroundStyle(.primary)

        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 18)
      .background(Color(uiColor: .secondarySystemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 24))
      .overlay {
        RoundedRectangle(cornerRadius: 24)
          .strokeBorder(Color(uiColor: .systemGray5), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .disabled(isSigningOut)
  }

  private func signOut() {
    Task {
      isSigningOut = true
      do {
        try await clerk.auth.signOut()
      } catch {
        print("Sign out error: \(error.localizedDescription)")
      }
      isSigningOut = false
    }
  }
}

#Preview {
  HomeView()
    .environment(Clerk.preview())
}
