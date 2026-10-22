//
//  SessionTaskChooseOrganizationView.swift
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct SessionTaskChooseOrganizationView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  @State private var accountLists = OrganizationScopedStore { OrganizationAccountListDataSource(scope: $0) }
  @State private var isSelectingOrganization = false

  let token: AuthFlowPresentationToken

  private var user: User? {
    clerk.user
  }

  private var scope: OrganizationUserScope? {
    OrganizationUserScope(
      clerk: clerk,
      includesCreationDefaults: clerk.environment?.organizationSettings.organizationCreationDefaults.enabled == true
    )
  }

  var body: some View {
    ZStack {
      Color.clear
        .frame(width: 0, height: 0)

      if let accountList = accountLists.content(for: scope) {
        content(accountList)
      }
    }
    .onChange(of: scope, initial: true) {
      accountLists.bind(scope)
    }
  }

  private func content(_ accountList: OrganizationAccountListDataSource) -> some View {
    @Bindable var accountList = accountList

    return Group {
      if !accountList.isLoading, !accountList.hasExistingResources, user?.createOrganizationEnabled == false {
        GetHelpView(context: .sessionTask(.organizationRequired))
          .navigationBarBackButtonHidden()
          #if os(iOS)
          .navigationBarTitleDisplayMode(.inline)
          #endif
          .preGlassSolidNavBar()
          .toolbar {
            UserButtonToolbarItem(presentationContext: .sessionTaskToolbar)
          }
      } else if !accountList.isLoading, !accountList.hasExistingResources {
        SessionTaskCreateOrganizationView(
          creationDefaults: accountList.creationDefaults,
          token: token
        )
      } else {
        Group {
          if accountList.isLoading {
            SpinnerView()
              .frame(width: 32, height: 32)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            chooseOrganizationContent(accountList)
          }
        }
        .background(theme.colors.background)
        .navigationBarBackButtonHidden()
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .preGlassSolidNavBar()
        .toolbar {
          UserButtonToolbarItem(presentationContext: .sessionTaskToolbar)
        }
      }
    }
    .clerkErrorPresenting($accountList.error, onDismiss: { _ in
      guard !accountList.hasExistingResources || accountList.hasFailedLists else { return }
      accountList.reload()
    })
  }

  // MARK: - Choose Organization

  private func chooseOrganizationContent(_ accountList: OrganizationAccountListDataSource) -> some View {
    ScrollView {
      VStack(spacing: 32) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Choose an organization")
          if user?.createOrganizationEnabled == true {
            HeaderView(style: .subtitle, text: "Join an existing organization or create a new one")
          } else {
            HeaderView(style: .subtitle, text: "Join an existing organization")
          }
        }
        .padding(.horizontal, 16)

        OrganizationAccountListSections(
          accountList: accountList,
          mode: .requiredOrganization,
          onSelection: { selection in
            switch selection {
            case .personalAccount:
              break
            case .organization(let id):
              Task { await selectOrganization(id: id, accountList) }
            }
          },
          onCreateOrganization: {
            guard clerk.authFlowPresentationIsCurrent(token) else { return }
            navigation.appendPostAuthDestination(
              .sessionTaskCreateOrganization(
                creationDefaults: accountList.creationDefaults,
                token: token
              )
            )
          }
        )
        .disabled(
          isSelectingOrganization ||
            !clerk.authFlowPresentationIsCurrent(token)
        )

        SecuredByClerkView()
          .padding(.horizontal, 16)
      }
      .padding(.vertical, 16)
    }
  }

  // MARK: - Actions

  private func selectOrganization(id: String, _ accountList: OrganizationAccountListDataSource) async {
    guard clerk.authFlowPresentationIsCurrent(token),
          !isSelectingOrganization,
          let session = clerk.session
    else {
      return
    }

    isSelectingOrganization = true
    defer { isSelectingOrganization = false }

    do {
      try await clerk.auth.setActive(sessionId: session.id, organizationId: id)
      guard clerk.authFlowPresentationIsCurrent(token) else { return }
      _ = clerk.finishAuthFlowPresentation(token)
    } catch {
      accountList.error = organizationError(from: error)
    }
  }

  private func organizationError(from error: Error) -> Error {
    if let clerkError = error as? ClerkAPIError,
       ["organization_not_found_or_unauthorized", "not_a_member_in_organization"].contains(clerkError.code)
    {
      if user?.createOrganizationEnabled == true {
        return ClerkClientError(message: "You are no longer a member of this organization. Please choose or create another one.", localizationBundle: .module)
      } else {
        return ClerkClientError(message: "You are no longer a member of this organization. Please choose another one.", localizationBundle: .module)
      }
    }
    return error
  }
}

#endif
