//
//  OrganizationMembersRows.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import NukeUI
import SwiftUI

// MARK: - Rows

struct OrganizationMemberRow: View {
  @Environment(\.clerkTheme) private var theme

  let membership: OrganizationMembership
  let roleName: String
  let roles: [RoleResource]
  let isCurrentUser: Bool
  let canManageMemberships: Bool
  let hasRoleSetMigration: Bool
  let isMutating: Bool
  let onUpdateRole: (RoleResource) async -> Void
  let onRemove: () async -> Void

  private var publicUserData: PublicUserData? {
    membership.publicUserData
  }

  private var displayName: String? {
    publicUserData?.displayName
  }

  private var identifier: String? {
    publicUserData?.identifier
  }

  private var joinedDate: String {
    membership.createdAt.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits).year())
  }

  private var roleMenuIsDisabled: Bool {
    roles.isEmpty || hasRoleSetMigration || isMutating
  }

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      HStack(alignment: .top, spacing: 16) {
        OrganizationMemberAvatarView(userData: publicUserData)

        VStack(alignment: .leading, spacing: 4) {
          if isCurrentUser {
            Text("You", bundle: .module)
              .font(theme.fonts.footnote)
              .foregroundStyle(theme.colors.mutedForeground)
              .padding(.horizontal, 6)
              .frame(height: 18)
              .background(theme.colors.background)
              .clipShape(.rect(cornerRadius: theme.design.borderRadius))
              .overlay {
                RoundedRectangle(cornerRadius: theme.design.borderRadius)
                  .strokeBorder(theme.colors.buttonBorder, lineWidth: 1)
              }
          }

          if let displayName {
            Text(verbatim: displayName)
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.foreground)
              .lineLimit(1)
          }

          if let identifier, !identifier.isEmpty {
            Text(verbatim: identifier)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.mutedForeground)
              .lineLimit(1)
          }

          if isCurrentUser {
            Text(verbatim: "\(roleName) · Joined \(joinedDate)")
              .font(theme.fonts.footnote)
              .foregroundStyle(theme.colors.mutedForeground)
              .lineLimit(1)
          } else {
            Text(verbatim: roleName)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.mutedForeground)
              .lineLimit(1)
            Text(verbatim: "Joined \(joinedDate)")
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.mutedForeground)
              .lineLimit(1)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if canManageMemberships {
        memberMenu
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .background(theme.colors.background)
  }

  private var memberMenu: some View {
    Menu {
      Menu {
        ForEach(roles) { role in
          AsyncButton {
            await onUpdateRole(role)
          } label: { _ in
            Label {
              Text(verbatim: role.name)
            } icon: {
              if role.key == membership.role {
                Image(systemName: "checkmark")
              }
            }
          }
          .disabled(role.key == membership.role || isMutating)
        }
      } label: {
        Text("Change role", bundle: .module)
      }
      .disabled(roleMenuIsDisabled)

      AsyncButton(role: .destructive) {
        await onRemove()
      } label: { _ in
        Text("Remove member", bundle: .module)
      }
      .disabled(isCurrentUser || isMutating)
    } label: {
      ThreeDotsMenuLabel()
    }
    .frame(width: 30, height: 30)
    .menuIndicator(.hidden)
  }
}

struct OrganizationInvitationRow: View {
  @Environment(\.clerkTheme) private var theme

  let invitation: OrganizationInvitation
  let roleName: String
  let isRevoking: Bool
  let onRevoke: () async -> Void

  private var invitedDate: String {
    invitation.createdAt.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits).year())
  }

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      HStack(alignment: .top, spacing: 16) {
        OrganizationInvitationAvatarView(emailAddress: invitation.emailAddress)

        VStack(alignment: .leading, spacing: 4) {
          Text(verbatim: invitation.emailAddress)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.foreground)
            .lineLimit(1)

          Text(verbatim: roleName)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .lineLimit(1)

          Text(verbatim: "Invited \(invitedDate)")
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      invitationMenu
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .background(theme.colors.background)
  }

  private var invitationMenu: some View {
    Menu {
      AsyncButton(role: .destructive) {
        await onRevoke()
      } label: { _ in
        Text("Revoke invitation", bundle: .module)
      }
      .disabled(isRevoking)
    } label: {
      ThreeDotsMenuLabel()
    }
    .frame(width: 30, height: 30)
    .menuIndicator(.hidden)
  }
}

struct OrganizationMembershipRequestRow: View {
  @Environment(\.clerkTheme) private var theme

  let request: OrganizationMembershipRequest
  let isAccepting: Bool
  let isRejecting: Bool
  let onAccept: () async -> Void
  let onReject: () async -> Void

  private var publicUserData: PublicUserData? {
    request.publicUserData
  }

  private var displayName: String? {
    publicUserData?.displayName
  }

  private var identifier: String? {
    publicUserData?.identifier
  }

  private var requestedDate: String {
    request.createdAt.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits).year())
  }

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      HStack(alignment: .top, spacing: 16) {
        OrganizationMemberAvatarView(userData: publicUserData)

        VStack(alignment: .leading, spacing: 4) {
          if let displayName {
            Text(verbatim: displayName)
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.foreground)
              .lineLimit(1)
          }

          if let identifier, !identifier.isEmpty {
            Text(verbatim: identifier)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.mutedForeground)
              .lineLimit(1)
          }

          Text(verbatim: "Requested \(requestedDate)")
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      requestMenu
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .background(theme.colors.background)
  }

  private var requestMenu: some View {
    Menu {
      AsyncButton {
        await onAccept()
      } label: { _ in
        Text("Accept request", bundle: .module)
      }
      .disabled(isAccepting || isRejecting)

      AsyncButton(role: .destructive) {
        await onReject()
      } label: { _ in
        Text("Reject request", bundle: .module)
      }
      .disabled(isAccepting || isRejecting)
    } label: {
      ThreeDotsMenuLabel()
    }
    .frame(width: 30, height: 30)
    .menuIndicator(.hidden)
  }
}

// MARK: - Avatars

struct OrganizationMemberAvatarView: View {
  @Environment(\.clerkTheme) private var theme

  let userData: PublicUserData?

  private var initials: String {
    let source = userData?.displayName ?? userData?.identifier ?? ""
    let parts = source
      .split(separator: " ")
      .prefix(2)
      .compactMap(\.first)

    let initials = String(parts).uppercased()
    if !initials.isEmpty {
      return initials
    }

    return String(source.prefix(1)).uppercased()
  }

  var body: some View {
    LazyImage(url: URL(string: userData?.imageUrl ?? "")) { state in
      if let image = state.image {
        image
          .resizable()
          .scaledToFill()
      } else {
        initialsView
      }
    }
    .frame(width: 36, height: 36)
    .clipShape(.circle)
  }

  private var initialsView: some View {
    ZStack {
      Circle()
        .fill(theme.colors.primary.gradient)

      Text(verbatim: initials)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(theme.colors.primaryForeground)
    }
  }
}

struct OrganizationInvitationAvatarView: View {
  @Environment(\.clerkTheme) private var theme

  let emailAddress: String

  private var initials: String {
    let localPart = emailAddress.split(separator: "@", maxSplits: 1).first.map(String.init) ?? emailAddress
    let parts = localPart
      .split { !$0.isLetter && !$0.isNumber }
      .prefix(2)
      .compactMap(\.first)

    let initials = String(parts).uppercased()
    if !initials.isEmpty {
      return initials
    }

    return String(emailAddress.prefix(1)).uppercased()
  }

  var body: some View {
    ZStack {
      Circle()
        .fill(theme.colors.primary.gradient)

      Text(verbatim: initials)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(theme.colors.primaryForeground)
    }
    .frame(width: 36, height: 36)
  }
}

extension PublicUserData {
  fileprivate var displayName: String? {
    let name = [firstName, lastName]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")

    return name.isEmpty ? nil : name
  }
}

#endif
