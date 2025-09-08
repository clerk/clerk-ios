//
//  UserProfileDevicesSection.swift
//  Clerk
//
//  Created by Mike Pitre on 5/13/25.
//

#if os(iOS)

  import SwiftUI

  struct UserProfileDevicesSection: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme

    var user: User? {
      clerk.user
    }

    var sortedSessions: [Session] {
      guard let user else { return [] }
      let sessions = (clerk.sessionsByUserId[user.id] ?? []).filter { $0.latestActivity != nil }
      return sessions.sorted { lhs, rhs in
        if lhs.isThisDevice {
          return true
        } else if rhs.isThisDevice {
          return false
        } else {
          return lhs.lastActiveAt > rhs.lastActiveAt
        }
      }
    }

    var body: some View {
      Section {
        VStack(spacing: 0) {
          ForEach(sortedSessions) { session in
            UserProfileDeviceRow(session: session)
          }
        }
        .background(theme.colors.background)
      } header: {
        UserProfileSectionHeader(text: "ACTIVE DEVICES")
      }
    }
  }

  #Preview {
    UserProfileDevicesSection()
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
