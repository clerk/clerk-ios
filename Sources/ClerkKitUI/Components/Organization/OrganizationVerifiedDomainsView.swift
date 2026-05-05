//
//  OrganizationVerifiedDomainsView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationVerifiedDomainsView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var domainsPager = OrganizationAccountListPager<OrganizationDomain>()
  @State private var isLoadingDomains = true
  @State private var addDomainIsPresented = false
  @State private var enrollmentModeDomain: OrganizationDomain?
  @State private var error: Error?

  private let pageSize = 10

  private var organization: Organization? {
    clerk.organization
  }

  private var organizationMembership: OrganizationMembership? {
    clerk.organizationMembership
  }

  private var canReadDomains: Bool {
    organizationMembership?.canReadDomains == true
  }

  private var canManageDomains: Bool {
    organizationMembership?.canManageDomains == true
  }

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        LazyVStack(spacing: 0) {
          Divider()

          if isLoadingDomains, domainsPager.items.isEmpty {
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
                onLoadMore: loadMoreDomains
              ) { domain in
                OrganizationVerifiedDomainRow(
                  domain: domain,
                  canManageDomains: canManageDomains,
                  onVerify: {},
                  onManage: {
                    enrollmentModeDomain = domain
                  },
                  onDelete: {}
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
                addDomainIsPresented = true
              }
              Divider()
            }
          }
        }
      }
      .refreshable {
        await loadDomains(page: 1)
      }

      SecuredByClerkFooter()
    }
    .tint(theme.colors.primary)
    .background(theme.colors.muted)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .navigationDestination(item: $enrollmentModeDomain) { domain in
      OrganizationDomainEnrollmentModeView(domain: domain) { updatedDomain in
        domainsPager.replace(updatedDomain)
      }
    }
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Verified domains", bundle: .module)
          .font(theme.fonts.headline)
          .fontWeight(.semibold)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    .clerkErrorPresenting($error)
    .sheet(isPresented: $addDomainIsPresented) {
      OrganizationAddDomainView {
        Task {
          await revalidateLoadedDomains()
        }
      }
    }
    .task(id: organization?.id) {
      await loadDomains(page: 1)
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

// MARK: - Actions

extension OrganizationVerifiedDomainsView {
  @MainActor
  private func loadDomains(page: Int) async {
    guard let organization, canReadDomains || canManageDomains else {
      isLoadingDomains = false
      domainsPager = OrganizationAccountListPager()
      return
    }

    isLoadingDomains = true
    defer { isLoadingDomains = false }

    do {
      let page = try await organization.getDomains(page: page, pageSize: pageSize)
      domainsPager.replace(with: page)
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load organization domains", error: error)
    }
  }

  @MainActor
  private func revalidateLoadedDomains() async {
    guard let organization, canReadDomains || canManageDomains else {
      isLoadingDomains = false
      domainsPager = OrganizationAccountListPager()
      return
    }

    let offsets = domainsPager.loadedPageOffsets(pageSize: pageSize)

    isLoadingDomains = true
    defer { isLoadingDomains = false }

    do {
      let pages = try await withThrowingTaskGroup(
        of: (index: Int, page: ClerkPaginatedResponse<OrganizationDomain>).self
      ) { group in
        for (index, offset) in offsets.enumerated() {
          group.addTask {
            let page = try await organization.getDomains(offset: offset, pageSize: pageSize)
            return (index, page)
          }
        }

        var indexedPages: [(index: Int, page: ClerkPaginatedResponse<OrganizationDomain>)] = []
        for try await indexedPage in group {
          indexedPages.append(indexedPage)
        }

        return indexedPages
          .sorted { $0.index < $1.index }
          .map { $0.page }
      }
      domainsPager.replace(with: pages)
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to revalidate organization domains", error: error)
    }
  }

  @MainActor
  private func loadMoreDomains() async {
    guard let organization, !domainsPager.isLoadingMore, domainsPager.hasNextPage else { return }

    domainsPager.isLoadingMore = true
    defer { domainsPager.isLoadingMore = false }

    do {
      let page = try await organization.getDomains(offset: domainsPager.offset, pageSize: pageSize)
      domainsPager.append(page)
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to load more organization domains", error: error)
    }
  }
}

#Preview("Verified Domains") {
  NavigationStack {
    OrganizationVerifiedDomainsView()
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
        preview.services.organizationService.getOrganizationDomainsHandler = { _, _, _, _ in
          var unverifiedDomain = OrganizationDomain.mock
          unverifiedDomain.id = "domain_1"
          unverifiedDomain.name = "clerk.com"
          unverifiedDomain.verification.status = "unverified"

          var manualDomain = OrganizationDomain.mock
          manualDomain.id = "domain_2"
          manualDomain.name = "clerky.com"
          manualDomain.enrollmentMode = OrganizationDomain.EnrollmentMode.manualInvitation.rawValue
          manualDomain.verification.status = "verified"

          return ClerkPaginatedResponse(data: [unverifiedDomain, manualDomain], totalCount: 2)
        }
      })
  }
}

#endif
