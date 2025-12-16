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
  @Environment(\.colorScheme) private var colorScheme

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
    .background(pageBackground.ignoresSafeArea())
  }

  private var pageBackground: Color {
    switch colorScheme {
    case .dark:
      Color(uiColor: .secondarySystemBackground)
    default:
      Color(uiColor: .systemBackground)
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

  private var displayName: String {
    let firstName = clerk.user?.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return firstName.isEmpty ? "Guest" : firstName
  }

  private var profileCard: some View {
    HStack(spacing: 20) {
      VStack(spacing: 12) {
        ZStack(alignment: .bottomTrailing) {
          avatar
            .frame(width: 112, height: 112)
            .clipShape(.circle)

          // Verified badge (non-functional, visual only)
          Circle()
            .fill(Color(red: 0.87, green: 0.0, blue: 0.35))
            .frame(width: 36, height: 36)
            .overlay {
              Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            }
            .offset(x: 6, y: 6)
        }

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

      statsColumn
    }
    .padding(20)
    .airbnbCardSurface(cornerRadius: 28)
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
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(.primary)
      Text(label)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
        .lineLimit(2) // reserve the same label space for all rows to avoid "staggered" layout
        .frame(height: 34, alignment: .topLeading)
    }
    .frame(height: 62, alignment: .topLeading)
  }

  private var statSeparator: some View {
    Rectangle()
      .fill(Color(uiColor: .systemGray5))
      .frame(height: 1)
      .padding(.vertical, 12)
  }

  private var statsColumn: some View {
    VStack(alignment: .leading, spacing: 0) {
      statRow(value: "7", label: "Trips")
      statSeparator
      statRow(value: "5", label: "Reviews")
      statSeparator
      statRow(value: "12", label: "Years on Airbnb")
    }
    .frame(width: 140, alignment: .leading)
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
          .font(.system(size: 17))
          .foregroundStyle(.primary)

        Spacer()

        LoadingDotsView(color: .secondary, dotSize: 5, spacing: 5, travel: 3)
          .opacity(isSigningOut ? 1 : 0)
      }
      .padding(.vertical, 10)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(isSigningOut)
  }

  private func signOut() {
    Task {
      withAnimation(.easeInOut(duration: 0.2)) {
        isSigningOut = true
      }
      do {
        try await clerk.auth.signOut()
      } catch {
        print("Sign out error: \(error.localizedDescription)")
      }
      withAnimation(.easeInOut(duration: 0.2)) {
        isSigningOut = false
      }
    }
  }
}

#Preview {
  HomeView()
    .environment(Clerk.preview())
}
