//
//  OrganizationVerifiedDomainsView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct OrganizationVerifiedDomainsView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var store = OrganizationScopedStore { OrganizationDomainsDataSource(scope: $0) }
  @State private var presentedDomainFlow: PresentedDomainFlow?

  private var scope: OrganizationScope? {
    OrganizationScope(clerk: clerk)
  }

  var body: some View {
    ZStack {
      Color.clear
        .frame(width: 0, height: 0)

      if let domains = store.content(for: scope) {
        content(domains)
      }
    }
    .onChange(of: scope, initial: true) {
      store.bind(scope)
    }
  }

  private func content(_ domains: OrganizationDomainsDataSource) -> some View {
    @Bindable var domains = domains

    return ScrollView {
      LazyVStack(spacing: 0) {
        Divider()

        rows(domains)
      }
    }
    .refreshable {
      await domains.list.refresh()
    }
    .tint(theme.colors.primary)
    .background(theme.colors.muted)
    .securedByClerkFooter()
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Verified domains", bundle: .module)
          .font(theme.fonts.headline)
          .fontWeight(.semibold)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    .clerkErrorPresenting($domains.error)
    .clerkSheet(item: $presentedDomainFlow) { presentedDomainFlow in
      view(for: presentedDomainFlow, domains: domains)
    }
    #if os(macOS)
    .frame(minWidth: 460, maxWidth: 620, alignment: .leading)
    #endif
  }

  @ViewBuilder
  private func rows(_ domains: OrganizationDomainsDataSource) -> some View {
    let domainsPager = domains.list.pager
    let canManageDomains = domains.scope.access.contains(.manageDomains)

    if domains.list.isLoading, domainsPager.items.isEmpty {
      SpinnerView()
        .frame(width: 24, height: 24)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    } else {
      if domainsPager.items.isEmpty, !canManageDomains {
        Text("No verified domains", bundle: .module)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.mutedForeground)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 32)
      } else {
        OrganizationPaginatedListSection(
          items: domainsPager.items,
          hasNextPage: domainsPager.hasNextPage,
          onLoadMore: { domains.list.loadMore() }
        ) { domain in
          OrganizationVerifiedDomainRow(
            domain: domain,
            canManageDomains: canManageDomains,
            onVerify: {
              presentedDomainFlow = .verify(domain)
            },
            onManage: {
              presentedDomainFlow = .enrollmentMode(domain)
            },
            onDelete: {
              presentedDomainFlow = .delete(domain, from: domains)
            }
          )
        }

        if domainsPager.isLoadingMore {
          SpinnerView()
            .frame(width: 24, height: 24)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
      }

      if canManageDomains {
        OrganizationAddDomainRow {
          presentedDomainFlow = .add
        }
        Divider()
      }
    }
  }

  @ViewBuilder
  private func view(for presentedDomainFlow: PresentedDomainFlow, domains: OrganizationDomainsDataSource) -> some View {
    switch presentedDomainFlow {
    case .add:
      OrganizationAddDomainView(onDomainChanged: domains.domainChanged)
    case let .verify(domain):
      OrganizationDomainVerificationFlowSheet(domain: domain, onDomainChanged: domains.domainChanged)
    case let .enrollmentMode(domain):
      OrganizationDomainEnrollmentModeView(domain: domain, onDomainChanged: domains.domainChanged)
    case let .delete(domain, openedFrom):
      OrganizationDomainDeleteConfirmationView(domain: domain) { deletedDomain in
        Task { await openedFrom.domainDeleted(deletedDomain) }
      }
    }
  }
}

// MARK: - Subviews

private struct OrganizationVerifiedDomainRow: View {
  @Environment(\.clerkTheme) private var theme

  let domain: OrganizationDomain
  let canManageDomains: Bool
  let onVerify: () -> Void
  let onManage: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        OrganizationDomainEnrollmentBadge(domain: domain)

        Text(verbatim: domain.name)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.foreground)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if canManageDomains {
        domainMenu
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .background(theme.colors.background)
  }

  private var domainMenu: some View {
    Menu {
      if domain.isVerified {
        Button {
          onManage()
        } label: {
          Text("Manage", bundle: .module)
        }
      } else {
        Button {
          onVerify()
        } label: {
          Text("Verify", bundle: .module)
        }
      }

      Button(role: .destructive) {
        onDelete()
      } label: {
        Text("Delete", bundle: .module)
      }
    } label: {
      ThreeDotsMenuLabel()
    }
    .frame(width: 30, height: 30)
    .menuIndicator(.hidden)
  }
}

private struct OrganizationDomainEnrollmentBadge: View {
  let domain: OrganizationDomain

  var body: some View {
    if domain.isVerified {
      switch domain.enrollmentModeType {
      case .manualInvitation:
        Badge(key: "No automatic enrollment", style: .secondary)
      case .automaticInvitation:
        Badge(key: "Automatic invitations", style: .positive)
      case .automaticSuggestion:
        Badge(key: "Automatic suggestions", style: .positive)
      case .unknown:
        Badge(string: domain.enrollmentMode, style: .secondary)
      }
    } else {
      Badge(key: "Unverified", style: .warning)
    }
  }
}

private struct OrganizationAddDomainRow: View {
  @Environment(\.clerkTheme) private var theme

  let onAddDomain: () -> Void

  var body: some View {
    Button {
      onAddDomain()
    } label: {
      VStack(alignment: .leading, spacing: 4) {
        Text("Add domain", bundle: .module)
          .font(theme.fonts.body)
          .fontWeight(.semibold)
          .foregroundStyle(theme.colors.primary)

        Text(
          "Allow users to join the organization automatically or request to join based on a verified email domain.",
          bundle: .module
        )
        .font(theme.fonts.subheadline)
        .foregroundStyle(theme.colors.mutedForeground)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
      .background(theme.colors.background)
    }
    .buttonStyle(.pressedBackground)
  }
}

private struct OrganizationDomainVerificationFlowSheet: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  let domain: OrganizationDomain
  let onDomainChanged: @MainActor () -> Void

  @State private var path: [Destination] = []
  @State private var codeLimiter = CodeLimiter()

  private enum Destination: Hashable {
    case verifyCode(OrganizationDomain, affiliationEmailAddress: String)
  }

  var body: some View {
    NavigationStack(path: $path) {
      OrganizationDomainEmailAddressView(domain: domain) { preparedDomain, affiliationEmailAddress in
        path.append(.verifyCode(preparedDomain, affiliationEmailAddress: affiliationEmailAddress))
      }
      .toolbar {
        CancelToolbarItem {
          dismiss()
        }
      }
      .navigationDestination(for: Destination.self) { destination in
        switch destination {
        case let .verifyCode(domain, affiliationEmailAddress):
          OrganizationDomainVerifyCodeView(
            domain: domain,
            emailAddress: affiliationEmailAddress
          ) {
            onDomainChanged()
            dismiss()
          }
        }
      }
    }
    .environment(codeLimiter)
    #if os(macOS)
    .frame(minWidth: 420, maxWidth: 520)
    #endif
  }
}

private enum PresentedDomainFlow: Identifiable {
  case add
  case verify(OrganizationDomain)
  case enrollmentMode(OrganizationDomain)
  case delete(OrganizationDomain, from: OrganizationDomainsDataSource)

  var id: String {
    switch self {
    case .add: "add"
    case let .verify(domain): "verify-\(domain.id)"
    case let .enrollmentMode(domain): "enrollmentMode-\(domain.id)"
    case let .delete(domain, _): "delete-\(domain.id)"
    }
  }
}

#Preview("Verified Domains") {
  @Previewable @State var navigationPath = NavigationPath()

  NavigationStack(path: $navigationPath) {
    OrganizationVerifiedDomainsView()
      .environment(
        OrganizationProfileBuiltInRouter(
          push: { destination in
            navigationPath.append(destination)
          },
          dismissAction: { action in
            switch action {
            case .popToRoot, .exitOrganizationProfile:
              navigationPath = NavigationPath()
            }
          }
        )
      )
      .environment(Clerk.preview { preview in
        var membership = OrganizationMembership.mockWithUserData
        membership.permissions = [
          OrganizationSystemPermission.readDomains.rawValue,
          OrganizationSystemPermission.manageDomains.rawValue,
        ]

        var user = User.mock
        user.organizationMemberships = [membership]

        var session = Session.mock
        session.lastActiveOrganizationId = membership.organization.id
        session.user = user

        var client = Client.mock
        client.sessions = [session]
        client.lastActiveSessionId = session.id

        var environment = Clerk.Environment.mock
        environment.organizationSettings.domains.enabled = true

        preview.client = client
        preview.environment = environment
        preview.transport.stub(OrganizationAPI.getDomains(organizationId: FakeTransport.anyPathSegment, offset: 0, pageSize: 0, enrollmentMode: nil)) { _ in
          var unverifiedDomain = OrganizationDomain.mock
          unverifiedDomain.id = "domain_1"
          unverifiedDomain.name = "clerk.com"
          unverifiedDomain.verification = .init(status: "unverified", strategy: "strategy", attempts: 0)

          var manualDomain = OrganizationDomain.mock
          manualDomain.id = "domain_2"
          manualDomain.name = "clerky.com"
          manualDomain.enrollmentMode = OrganizationDomain.EnrollmentMode.manualInvitation.rawValue
          manualDomain.verification = .init(status: "verified", strategy: "strategy", attempts: 0)

          return ClientResponse(response: ClerkPaginatedResponse(data: [unverifiedDomain, manualDomain], totalCount: 2), client: nil)
        }
      })
  }
}

#endif
