//
//  UserProfileDeviceRow.swift
//  Clerk
//
//  Created by Mike Pitre on 5/13/25.
//

#if os(iOS)

  import SwiftUI

  struct UserProfileDeviceRow: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme

    @State private var isLoading = false
    @State private var error: Error?

    var user: User? {
      clerk.user
    }

    let session: Session

    var body: some View {
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
                  .foregroundStyle(theme.colors.text)
                  .frame(minHeight: 22)

                VStack(alignment: .leading, spacing: 0) {
                  Group {
                    Text(verbatim: activity.browserFormatted)
                    Text(verbatim: activity.ipAndLocationFormatted)
                    Text(session.lastActiveAt.relativeNamedFormat)
                  }
                  .font(theme.fonts.subheadline)
                  .foregroundStyle(theme.colors.textSecondary)
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
            Image("icon-three-dots-vertical", bundle: .module)
              .resizable()
              .scaledToFit()
              .foregroundColor(theme.colors.textSecondary)
              .frame(width: 20, height: 20)
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
    }
  }

  extension UserProfileDeviceRow {

    func signOutOfDevice() async {
      do {
        try await session.revoke()
        try await user?.getSessions()
      } catch {
        self.error = error
      }
    }

  }

  #Preview {
    UserProfileDeviceRow(session: .mock)
      .environment(\.clerk, .mock)
  }

#endif
