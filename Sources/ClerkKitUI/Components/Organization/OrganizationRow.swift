//
//  OrganizationRow.swift
//

#if os(iOS)

import SwiftUI

struct OrganizationRow<Accessory: View>: View {
  @Environment(\.clerkTheme) private var theme

  let name: String
  let imageUrl: String
  let subtitle: Text?
  let accessory: Accessory

  init(
    name: String,
    imageUrl: String,
    subtitle: String? = nil,
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.name = name
    self.imageUrl = imageUrl
    self.subtitle = subtitle.map { Text(verbatim: $0) }
    self.accessory = accessory()
  }

  init(
    name: String,
    imageUrl: String,
    subtitle: String,
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.name = name
    self.imageUrl = imageUrl
    self.subtitle = Text(verbatim: subtitle)
    self.accessory = accessory()
  }

  init(
    name: String,
    imageUrl: String,
    subtitle: LocalizedStringKey,
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.name = name
    self.imageUrl = imageUrl
    self.subtitle = Text(subtitle, bundle: .module)
    self.accessory = accessory()
  }

  var body: some View {
    HStack(spacing: 16) {
      OrganizationAvatarView(name: name, imageUrl: imageUrl)

      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: name)
          .font(.body)
          .foregroundStyle(theme.colors.foreground)
          .lineLimit(1)

        if let subtitle {
          subtitle
            .font(.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .lineLimit(1)
        }
      }

      Spacer()

      accessory
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
    .contentShape(Rectangle())
  }
}

extension OrganizationRow where Accessory == EmptyView {
  init(name: String, imageUrl: String) {
    self.init(name: name, imageUrl: imageUrl) {
      EmptyView()
    }
  }

  init(name: String, imageUrl: String, subtitle: String?) {
    self.init(name: name, imageUrl: imageUrl, subtitle: subtitle) {
      EmptyView()
    }
  }

  init(name: String, imageUrl: String, subtitle: String) {
    self.init(name: name, imageUrl: imageUrl, subtitle: subtitle) {
      EmptyView()
    }
  }

  init(name: String, imageUrl: String, subtitle: LocalizedStringKey) {
    self.init(name: name, imageUrl: imageUrl, subtitle: subtitle) {
      EmptyView()
    }
  }
}

#Preview {
  VStack(spacing: 0) {
    OrganizationRow(
      name: "Acme Inc.",
      imageUrl: "",
      subtitle: "Admin"
    )
    Divider()
    OrganizationRow(name: "Test Organization", imageUrl: "") {
      PillButtonLabelView("Join")
    }
  }
  .environment(\.clerkTheme, .clerk)
}

#endif
