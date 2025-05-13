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

    let session: Session

    var body: some View {
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
                  Text(session.lastActiveAt.formatted(Date.RelativeFormatStyle()))
                }
                .font(theme.fonts.subheadline)
                .foregroundStyle(theme.colors.textSecondary)
                .frame(minHeight: 20)
              }
            }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
      .overlay(alignment: .bottom) {
        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)
      }
      .buttonStyle(.pressedBackground)
      .simultaneousGesture(TapGesture())
    }
  }

  #Preview {
    UserProfileDeviceRow(session: .mock)
      .environment(\.clerk, .mock)
  }

#endif
