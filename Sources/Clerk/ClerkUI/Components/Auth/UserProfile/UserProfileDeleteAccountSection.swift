//
//  UserProfileDeleteAccountSection.swift
//  Clerk
//
//  Created by Mike Pitre on 5/13/25.
//

import SwiftUI

struct UserProfileDeleteAccountSection: View {
  @Environment(\.clerkTheme) private var theme
    
  var body: some View {
    Section {
      UserProfileButtonRow(text: "Delete account", style: .danger) {
        //
      }
      .background(theme.colors.background)
    } header: {
      UserProfileSectionHeader(text: "DELETE ACCOUNT")
    }

  }
}

#Preview {
  UserProfileDeleteAccountSection()
}
