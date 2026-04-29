//
//  OrganizationSelectedAccessory.swift
//

#if os(iOS)

import SwiftUI

struct OrganizationSelectedAccessory: View {
  @Environment(\.clerkTheme) private var theme

  var body: some View {
    Image(systemName: "checkmark")
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(theme.colors.primary)
      .accessibilityLabel(Text("Selected", bundle: .module))
  }
}

#Preview {
  OrganizationSelectedAccessory()
    .environment(\.clerkTheme, .clerk)
}

#endif
