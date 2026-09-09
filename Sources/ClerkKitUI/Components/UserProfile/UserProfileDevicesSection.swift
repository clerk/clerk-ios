//
//  UserProfileDevicesSection.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileDevicesSection: View {
  @Environment(Clerk.self) private var clerk
  @Environment(UserProfileData.self) private var profileData
  @Environment(\.clerkTheme) private var theme

  private var user: User? {
    clerk.user
  }

  private var sortedSessions: [SessionWithActivities] {
    let sessions = profileData.sessions
    return sessions.sorted { lhs, rhs in
      if lhs.id == clerk.session?.id {
        true
      } else if rhs.id == clerk.session?.id {
        false
      } else {
        lhs.lastActiveAt > rhs.lastActiveAt
      }
    }
  }

  var body: some View {
    Section {
      VStack(spacing: 0) {
        ForEach(sortedSessions, id: \.id) { session in
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
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
