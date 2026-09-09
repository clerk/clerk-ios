//
//  OrganizationProfileUpdateProfileView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct OrganizationProfileUpdateProfileView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  private let organization: Organization

  init(organization: Organization) {
    self.organization = organization
  }

  var body: some View {
    NavigationStack {
      OrganizationProfileFormView(
        organization: organization
      )
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .preGlassSolidNavBar()
      .toolbar {
        CancelToolbarItem {
          dismiss()
        }

        ToolbarItem(placement: .principal) {
          Text("Update profile", bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 420, maxWidth: 520)
    #endif
    .presentationBackground(theme.colors.background)
    .background(theme.colors.background)
  }
}

#Preview {
  OrganizationProfileUpdateProfileView(organization: .mock)
    .environment(Clerk.preview(.profile))
}

#endif
