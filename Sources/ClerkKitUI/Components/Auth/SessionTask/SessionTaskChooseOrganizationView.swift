//
//  SessionTaskChooseOrganizationView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

/// A view shown when a session requires the user to choose or create an organization
/// before the session can become active.
struct SessionTaskChooseOrganizationView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  @State private var accountList = OrganizationAccountListModel()
  @State private var isSelectingOrganization = false

  private var user: User? {
    clerk.user
  }

  var body: some View {
    Group {
      if !accountList.isLoading, !accountList.hasExistingResources, user?.createOrganizationEnabled == false {
        GetHelpView(context: .sessionTask(.organizationRequired))
          .navigationBarBackButtonHidden()
          .navigationBarTitleDisplayMode(.inline)
          .preGlassSolidNavBar()
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              UserButton(presentationContext: .sessionTaskToolbar)
            }
          }
      } else if !accountList.isLoading, !accountList.hasExistingResources {
        SessionTaskCreateOrganizationView(creationDefaults: accountList.creationDefaults)
      } else {
        Group {
          if accountList.isLoading {
            SpinnerView()
              .frame(width: 32, height: 32)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            chooseOrganizationContent
          }
        }
        .background(theme.colors.background)
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .preGlassSolidNavBar()
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            UserButton(presentationContext: .sessionTaskToolbar)
          }
        }
      }
    }
    .clerkErrorPresenting($accountList.error, onDismiss: { _ in
      guard !accountList.hasExistingResources, user != nil else { return }
      Task { await fetchOrganizationResources() }
    })
    .taskOnce {
      await fetchOrganizationResources()
    }
  }

  // MARK: - Choose Organization

  private var chooseOrganizationContent: some View {
    ScrollView {
      VStack(spacing: 32) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Choose an Organization")
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
              Task { await selectOrganization(id: id) }
            }
          },
          onCreateOrganization: {
            navigation.path.append(.sessionTaskCreateOrganization(creationDefaults: accountList.creationDefaults))
          }
        )
        .disabled(isSelectingOrganization)

        SecuredByClerkView()
          .padding(.horizontal, 16)
      }
      .padding(.vertical, 16)
    }
  }

  // MARK: - Actions

  private func fetchOrganizationResources() async {
    let defaultsEnabled = clerk.environment?.organizationSettings.organizationCreationDefaults.enabled == true
    await accountList.loadInitial(user: user, includeCreationDefaults: defaultsEnabled)
  }

  private func selectOrganization(id: String) async {
    guard !isSelectingOrganization, let session = clerk.session else { return }

    isSelectingOrganization = true
    defer { isSelectingOrganization = false }

    do {
      try await clerk.auth.setActive(sessionId: session.id, organizationId: id)
      navigation.handleSessionTaskCompletion(session: clerk.session)
    } catch {
      accountList.error = organizationError(from: error)
    }
  }

  private func organizationError(from error: Error) -> Error {
    if let clerkError = error as? ClerkAPIError,
       ["organization_not_found_or_unauthorized", "not_a_member_in_organization"].contains(clerkError.code)
    {
      if user?.createOrganizationEnabled == true {
        return ClerkClientError(message: "You are no longer a member of this organization. Please choose or create another one.")
      } else {
        return ClerkClientError(message: "You are no longer a member of this organization. Please choose another one.")
      }
    }
    return error
  }
}

#Preview("Choose Organization") {
  SessionTaskChooseOrganizationView()
    .clerkPreview()
}

#endif
