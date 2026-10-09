//
//  OrganizationAccountListSections.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct OrganizationAccountListSections: View {
  @Environment(Clerk.self) private var clerk

  let accountList: OrganizationAccountListDataSource
  let mode: OrganizationAccountListMode
  let onSelection: (OrganizationAccountListSelection) -> Void
  let onCreateOrganization: () -> Void

  private var user: User? {
    clerk.user
  }

  private var activeOrganization: Organization? {
    clerk.organization
  }

  var body: some View {
    LazyVStack(spacing: 0) {
      Divider()

      if let user, mode.showsPersonalAccount {
        Button {
          guard activeOrganization != nil else { return }
          onSelection(.personalAccount)
        } label: {
          OrganizationPersonalAccountRow(user: user) {
            if activeOrganization == nil {
              OrganizationSelectedAccessory()
            }
          }
        }
        .buttonStyle(.plain)
        Divider()
      }

      OrganizationPaginatedListSection(
        items: accountList.memberships.pager.items,
        hasNextPage: accountList.memberships.pager.hasNextPage,
        onLoadMore: {
          accountList.memberships.loadMore()
        }
      ) { membership in
        OrganizationAccountMembershipRow(
          membership: membership,
          isSelected: mode.showsSelectedAccessory && membership.organization.id == activeOrganization?.id,
          onSelectOrganization: {
            onSelection(.organization($0))
          }
        )
      }

      if !accountList.memberships.pager.hasNextPage {
        OrganizationPaginatedListSection(
          items: accountList.invitations.pager.items,
          hasNextPage: accountList.invitations.pager.hasNextPage,
          onLoadMore: {
            accountList.invitations.loadMore()
          }
        ) { invitation in
          OrganizationAccountInvitationRow(
            invitation: invitation,
            accountList: accountList,
            onSelectOrganization: {
              onSelection(.organization($0))
            }
          )
        }
      }

      if !accountList.memberships.pager.hasNextPage, !accountList.invitations.pager.hasNextPage {
        OrganizationPaginatedListSection(
          items: accountList.suggestions.pager.items,
          hasNextPage: accountList.suggestions.pager.hasNextPage,
          onLoadMore: {
            accountList.suggestions.loadMore()
          }
        ) { suggestion in
          OrganizationAccountSuggestionRow(
            suggestion: suggestion,
            accountList: accountList
          )
        }
      }

      if accountList.isLoadingMore {
        SpinnerView()
          .frame(width: 24, height: 24)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
      }

      if !accountList.hasNextPage, user?.createOrganizationEnabled == true {
        Button {
          onCreateOrganization()
        } label: {
          OrganizationCreateRow()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Organization.AccountList.createOrganizationButton)
        Divider()
      }
    }
  }
}

enum OrganizationAccountListMode: Hashable {
  case accountSwitcher(showsPersonalAccount: Bool)
  case requiredOrganization

  var showsPersonalAccount: Bool {
    switch self {
    case .accountSwitcher(let showsPersonalAccount):
      showsPersonalAccount
    case .requiredOrganization:
      false
    }
  }

  var showsSelectedAccessory: Bool {
    switch self {
    case .accountSwitcher:
      true
    case .requiredOrganization:
      false
    }
  }
}

enum OrganizationAccountListSelection: Hashable {
  case personalAccount
  case organization(String)
}

private struct OrganizationAccountMembershipRow: View {
  let membership: OrganizationMembership
  let isSelected: Bool
  let onSelectOrganization: (String) -> Void

  var body: some View {
    Button {
      guard !isSelected else { return }
      onSelectOrganization(membership.organization.id)
    } label: {
      OrganizationRow(
        name: membership.organization.name,
        imageUrl: membership.organization.imageUrl,
        subtitle: membership.roleName
      ) {
        if isSelected {
          OrganizationSelectedAccessory()
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Organization.AccountList.membershipButton)
  }
}

private struct OrganizationAccountInvitationRow: View {
  @Environment(\.locale) private var locale

  let invitation: UserOrganizationInvitation
  let accountList: OrganizationAccountListDataSource
  let onSelectOrganization: (String) -> Void

  private var roleName: String {
    switch invitation.role {
    case "org:admin": String(localizedInClerkUI: "Admin", locale: locale)
    case "org:member": String(localizedInClerkUI: "Member", locale: locale)
    default: invitation.role.replacingOccurrences(of: "org:", with: "").capitalized
    }
  }

  var body: some View {
    if invitation.isAccepted {
      Button {
        onSelectOrganization(invitation.publicOrganizationData.id)
      } label: {
        OrganizationRow(
          name: invitation.publicOrganizationData.name,
          imageUrl: invitation.publicOrganizationData.imageUrl,
          subtitle: roleName
        )
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Organization.AccountList.acceptedInvitationButton)
    } else {
      OrganizationRow(
        name: invitation.publicOrganizationData.name,
        imageUrl: invitation.publicOrganizationData.imageUrl
      ) {
        AsyncButton {
          await accountList.acceptInvitation(invitation)
        } label: { isRunning in
          PillButtonLabelView("Join", isLoading: isRunning)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Organization.AccountList.invitationJoinButton)
      }
    }
  }
}

private struct OrganizationAccountSuggestionRow: View {
  let suggestion: OrganizationSuggestion
  let accountList: OrganizationAccountListDataSource

  var body: some View {
    if suggestion.isAccepted {
      OrganizationRow(
        name: suggestion.publicOrganizationData.name,
        imageUrl: suggestion.publicOrganizationData.imageUrl,
        // A bare literal would pick the untranslated `String?` overload.
        subtitle: LocalizedStringKey("Pending approval")
      )
    } else {
      OrganizationRow(
        name: suggestion.publicOrganizationData.name,
        imageUrl: suggestion.publicOrganizationData.imageUrl
      ) {
        AsyncButton {
          await accountList.acceptSuggestion(suggestion)
        } label: { isRunning in
          PillButtonLabelView("Request to join", isLoading: isRunning)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

extension UserOrganizationInvitation {
  fileprivate var isAccepted: Bool {
    status == "accepted"
  }
}

extension OrganizationSuggestion {
  fileprivate var isAccepted: Bool {
    status == "accepted"
  }
}

#endif
