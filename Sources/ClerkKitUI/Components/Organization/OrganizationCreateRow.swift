//
//  OrganizationCreateRow.swift
//

#if os(iOS)

import SwiftUI

struct OrganizationCreateRow: View {
  @Environment(\.clerkTheme) private var theme

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: "plus")
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(theme.colors.foreground)
        .frame(width: 48)

      Text("Create organization", bundle: .module)
        .font(.body.weight(.semibold))
        .foregroundStyle(theme.colors.foreground)

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
    .contentShape(Rectangle())
  }
}

#Preview {
  OrganizationCreateRow()
    .environment(\.clerkTheme, .clerk)
}

#endif
