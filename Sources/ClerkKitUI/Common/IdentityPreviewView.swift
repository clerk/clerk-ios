//
//  IdentityPreviewView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

struct IdentityPreviewView: View {
  @Environment(\.clerkTheme) private var theme

  let label: String
  let isEnabled: Bool
  let onEdit: () -> Void

  init(
    label: String,
    isEnabled: Bool = true,
    onEdit: @escaping () -> Void
  ) {
    self.label = label
    self.isEnabled = isEnabled
    self.onEdit = onEdit
  }

  var body: some View {
    Button {
      onEdit()
    } label: {
      HStack(spacing: 4) {
        Text(label)
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.foreground)
          .frame(minHeight: 20)

        if isEnabled {
          Image("icon-edit", bundle: .module)
            .resizable()
            .frame(width: 16, height: 16)
            .scaledToFit()
            .foregroundStyle(theme.colors.mutedForeground)
        }
      }
    }
    .buttonStyle(.secondary(config: .init(size: .small)))
    .disabled(!isEnabled)
    .simultaneousGesture(TapGesture())
  }
}

#Preview {
  VStack(spacing: 20) {
    IdentityPreviewView(label: "example@email.com") {}
    IdentityPreviewView(label: "example@email.com", isEnabled: false) {}
  }
}

#endif
