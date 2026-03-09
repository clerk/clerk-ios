//
//  UserProfileDeviceRow.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileDeviceRow: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  let session: Session

  @State private var isLoading = false
  @State private var error: Error?

  private var user: User? {
    clerk.user
  }

  private var errorMessage: String? {
    error?.localizedDescription
  }

  var body: some View {
    #if os(iOS)
    HStack(spacing: 16) {
      HStack(alignment: .top) {
        if let activity = session.latestActivity {
          activity.deviceImage
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)

          VStack(alignment: .leading, spacing: 8) {
            if session.isThisDevice {
              Badge(key: "This device", style: .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
              activity.deviceText
                .font(theme.fonts.body)
                .foregroundStyle(theme.colors.foreground)
                .frame(minHeight: 22)

              VStack(alignment: .leading, spacing: 0) {
                Group {
                  Text(verbatim: activity.browserFormatted)
                  Text(verbatim: activity.ipAndLocationFormatted)
                  Text(session.lastActiveAt.relativeNamedFormat)
                }
                .font(theme.fonts.subheadline)
                .foregroundStyle(theme.colors.mutedForeground)
                .frame(minHeight: 20)
              }
            }
          }
        }
      }

      Spacer(minLength: 0)

      if !session.isThisDevice {
        Menu {
          AsyncButton(role: .destructive) {
            await signOutOfDevice()
          } label: { _ in
            Text("Sign out of device", bundle: .module)
          }
          .onIsRunningChanged { isLoading = $0 }
        } label: {
          ThreeDotsMenuLabel()
        }
        .frame(width: 30, height: 30)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .overlayProgressView(isActive: isLoading)
    .overlay(alignment: .bottom) {
      Rectangle()
        .frame(height: 1)
        .foregroundStyle(theme.colors.border)
    }
    .clerkErrorPresenting($error)
    .animation(.default, value: isLoading)
    #elseif os(macOS)
    VStack(alignment: .leading, spacing: 8) {
      if let activity = session.latestActivity {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: activity.isMobile == true ? "iphone" : "desktopcomputer")
            .frame(width: 20)
            .foregroundStyle(theme.colors.mutedForeground)

          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              Text(activity.deviceDescription)
                .font(theme.fonts.subheadline.weight(.medium))
                .foregroundStyle(theme.colors.foreground)

              if session.isThisDevice {
                Text("This device")
                  .font(theme.fonts.caption.weight(.semibold))
                  .foregroundStyle(theme.colors.foreground)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(theme.colors.muted, in: Capsule())
              }
            }

            if !activity.browserFormatted.isEmpty {
              Text(activity.browserFormatted)
                .font(theme.fonts.body)
                .foregroundStyle(theme.colors.mutedForeground)
            }

            Text(activity.ipAndLocationFormatted)
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.mutedForeground)

            Text(session.lastActiveAt.relativeNamedFormat)
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.mutedForeground)
          }

          Spacer()

          if !session.isThisDevice {
            Button("Sign Out") {
              Task {
                await signOutOfDevice()
              }
            }
            .buttonStyle(.secondary(config: .init(emphasis: .low, size: .small)))
            .disabled(isLoading)
          }
        }
      }

      if let errorMessage {
        Text(errorMessage)
          .font(theme.fonts.footnote)
          .foregroundStyle(theme.colors.danger)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    #endif
  }
}

extension UserProfileDeviceRow {
  @MainActor
  private func signOutOfDevice() async {
    #if os(macOS)
    error = nil
    isLoading = true
    defer { isLoading = false }
    #endif

    do {
      try await session.revoke()
      try await user?.getSessions()
    } catch {
      self.error = error
      ClerkLogger.error("Failed to sign out of device", error: error)
    }
  }
}

#Preview {
  #if os(iOS)
  UserProfileDeviceRow(session: .mock)
    .clerkPreview()
  #elseif os(macOS)
  UserProfileDeviceRow(session: .mock)
    .environment(Clerk.preview())
    .padding()
  #endif
}

#endif
