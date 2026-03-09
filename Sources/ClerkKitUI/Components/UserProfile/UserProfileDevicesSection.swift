//
//  UserProfileDevicesSection.swift
//  Clerk
//

import ClerkKit
import SwiftUI

struct UserProfileDevicesSection: View {
  @Environment(Clerk.self) private var clerk
  #if os(iOS)
  @Environment(\.clerkTheme) private var theme
  #endif

  private var user: User? {
    clerk.user
  }

  private var sortedSessions: [Session] {
    guard let user else { return [] }
    let sessions = (clerk.sessionsByUserId[user.id] ?? []).filter { $0.latestActivity != nil }
    return sessions.sorted { lhs, rhs in
      if lhs.isThisDevice {
        true
      } else if rhs.isThisDevice {
        false
      } else {
        lhs.lastActiveAt > rhs.lastActiveAt
      }
    }
  }

  var body: some View {
    #if os(iOS)
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
    #elseif os(macOS)
    if !sortedSessions.isEmpty {
      GroupBox("Active Devices") {
        VStack(alignment: .leading, spacing: 16) {
          ForEach(sortedSessions) { session in
            UserProfileDeviceRow(session: session)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    #endif
  }
}

#Preview {
  #if os(iOS)
  UserProfileDevicesSection()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
  #elseif os(macOS)
  UserProfileDevicesSection()
    .environment(Clerk.preview())
  #endif
}
