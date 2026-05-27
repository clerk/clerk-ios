//
//  OrganizationSwitcherLabel.swift
//

#if os(iOS)

import ClerkKit
import NukeUI
import SwiftUI

struct OrganizationSwitcherLabel: View {
  @Environment(\.clerkTheme) private var theme

  let organization: Organization?
  let user: User?
  let displayMode: OrganizationSwitcherDisplayMode
  @ScaledMetric(wrappedValue: 1, relativeTo: .title3) private var textScale: CGFloat

  init(
    organization: Organization?,
    user: User?,
    displayMode: OrganizationSwitcherDisplayMode = .normal
  ) {
    self.organization = organization
    self.user = user
    self.displayMode = displayMode
  }

  var body: some View {
    Label {
      Text(verbatim: title)
        .font(.system(size: metrics.fontSize, weight: .semibold))
        .foregroundStyle(theme.colors.foreground)
        .lineLimit(1)
        .truncationMode(.tail)
    } icon: {
      image(size: metrics.avatarSize)
    }
    .labelStyle(
      OrganizationSwitcherTriggerLabelStyle(
        displayMode: displayMode,
        metrics: metrics,
        chevronColor: theme.colors.mutedForeground
      )
    )
    .frame(
      minWidth: metrics.minimumTapTarget,
      minHeight: metrics.minimumTapTarget,
      alignment: .leading
    )
    .contentShape(Rectangle())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: title))
  }

  @ViewBuilder
  private func image(size: CGFloat) -> some View {
    let cornerRadius = theme.design.borderRadius

    if let organization {
      OrganizationAvatarView(
        name: organization.name,
        imageUrl: organization.imageUrl,
        size: size
      )
    } else if let user {
      LazyImage(url: URL(string: user.imageUrl)) { state in
        if let image = state.image {
          image
            .resizable()
            .scaledToFill()
        } else {
          RoundedRectangle(cornerRadius: cornerRadius)
            .fill(theme.colors.primary.gradient)
        }
      }
      .frame(width: size, height: size)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    } else {
      Image(systemName: "building.2")
        .font(.system(size: size * 0.54, weight: .semibold))
        .foregroundStyle(theme.colors.primaryForeground)
        .frame(width: size, height: size)
        .background(theme.colors.primary.gradient, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
  }

  private var metrics: OrganizationSwitcherLabelMetrics {
    let baseSize = max(1, displayMode.size)
    let scale = baseSize / OrganizationSwitcherLabelDefaults.baseSize

    return OrganizationSwitcherLabelMetrics(
      avatarSize: baseSize,
      spacing: OrganizationSwitcherLabelDefaults.spacing * scale,
      fontSize: OrganizationSwitcherLabelDefaults.fontSize * scale * textScale,
      chevronFrameSize: OrganizationSwitcherLabelDefaults.chevronFrameSize * scale,
      chevronSize: OrganizationSwitcherLabelDefaults.chevronSize * scale,
      minimumTapTarget: max(44, baseSize)
    )
  }

  private var title: String {
    if let organization {
      organization.name
    } else if user != nil {
      String(localized: "Personal account", bundle: .module)
    } else {
      String(localized: "Select organization", bundle: .module)
    }
  }
}

private enum OrganizationSwitcherLabelDefaults {
  static let baseSize: CGFloat = 36
  static let spacing: CGFloat = 8
  static let fontSize: CGFloat = 20
  static let chevronFrameSize: CGFloat = 24
  static let chevronSize: CGFloat = 12
}

private struct OrganizationSwitcherTriggerLabelStyle: LabelStyle {
  let displayMode: OrganizationSwitcherDisplayMode
  let metrics: OrganizationSwitcherLabelMetrics
  let chevronColor: Color

  func makeBody(configuration: Configuration) -> some View {
    switch displayMode.kind {
    case .normal:
      HStack(spacing: metrics.spacing) {
        configuration.icon

        configuration.title
          .frame(minWidth: 0, alignment: .leading)

        chevron
      }
      .frame(minHeight: metrics.minimumTapTarget, alignment: .leading)
    case .compact:
      configuration.icon
        .frame(
          width: metrics.minimumTapTarget,
          height: metrics.minimumTapTarget,
          alignment: .leading
        )
    }
  }

  private var chevron: some View {
    Image(systemName: "chevron.down")
      .font(.system(size: metrics.chevronSize, weight: .semibold))
      .foregroundStyle(chevronColor)
      .frame(width: metrics.chevronFrameSize, height: metrics.chevronFrameSize)
  }
}

private struct OrganizationSwitcherLabelMetrics {
  let avatarSize: CGFloat
  let spacing: CGFloat
  let fontSize: CGFloat
  let chevronFrameSize: CGFloat
  let chevronSize: CGFloat
  let minimumTapTarget: CGFloat
}

#Preview("Organization Switcher Label Sizes") {
  VStack(alignment: .leading, spacing: 16) {
    OrganizationSwitcherLabel(organization: .mock, user: nil)
    OrganizationSwitcherLabel(organization: .mock, user: nil, displayMode: .normal(size: 36))
    OrganizationSwitcherLabel(organization: .mock, user: nil, displayMode: .compact)
    OrganizationSwitcherLabel(organization: .mock, user: nil, displayMode: .compact(size: 36))
    OrganizationSwitcherLabel(organization: .mock, user: nil, displayMode: .normal(size: 48))
  }
  .padding()
  .environment(\.clerkTheme, .clerk)
}

#Preview("Organization Switcher Label Widths") {
  let organization = {
    var organization = Organization.mock
    organization.name = "Acme International Product Research and Operations"
    return organization
  }()

  VStack(alignment: .leading, spacing: 16) {
    OrganizationSwitcherLabel(organization: organization, user: nil)
      .frame(maxWidth: 320, alignment: .leading)
    OrganizationSwitcherLabel(organization: organization, user: nil)
      .frame(maxWidth: 220, alignment: .leading)
    OrganizationSwitcherLabel(organization: organization, user: nil, displayMode: .normal(size: 28))
      .frame(maxWidth: 180, alignment: .leading)
    OrganizationSwitcherLabel(organization: organization, user: nil, displayMode: .compact)
  }
  .padding()
  .environment(\.clerkTheme, .clerk)
}

#Preview("Organization Switcher Label States") {
  let missingImageOrganization = {
    var organization = Organization.mock
    organization.imageUrl = ""
    return organization
  }()

  VStack(alignment: .leading, spacing: 16) {
    OrganizationSwitcherLabel(organization: missingImageOrganization, user: nil)
    OrganizationSwitcherLabel(organization: nil, user: .mock)
    OrganizationSwitcherLabel(organization: nil, user: nil)
  }
  .padding()
  .environment(\.clerkTheme, .clerk)
}

#Preview("Organization Switcher Label Accessibility Size") {
  VStack(alignment: .leading, spacing: 16) {
    OrganizationSwitcherLabel(organization: .mock, user: nil)
    OrganizationSwitcherLabel(organization: .mock, user: nil, displayMode: .compact)
  }
  .padding()
  .environment(\.dynamicTypeSize, .accessibility3)
  .environment(\.clerkTheme, .clerk)
}

#endif
