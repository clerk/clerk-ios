//
//  OrganizationProfileActionConfirmationView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationProfileActionConfirmationView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(OrganizationProfileBuiltInRouter.self) private var builtInRouter

  let action: OrganizationProfileActionConfirmation
  let organization: Organization

  @State private var confirmation = ""
  @State private var error: Error?
  @FocusState private var isFocused: Bool

  private var buttonIsDisabled: Bool {
    confirmation.confirmationNormalized != organization.name.confirmationNormalized
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          VStack(alignment: .leading, spacing: 8) {
            Text(action.messageLine1, bundle: .module)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.mutedForeground)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .leading)

            Text(action.messageLine2, bundle: .module)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.danger)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("Type \"\(organization.name)\" below to continue.", bundle: .module)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.foreground)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .leading)

            ClerkTextField("Organization name", text: $confirmation)
              .autocorrectionDisabled()
              .textInputAutocapitalization(.never)
              .focused($isFocused)
              .onFirstAppear {
                isFocused = true
              }

            if let error {
              ErrorText(error: error, alignment: .leading)
                .font(theme.fonts.subheadline)
                .transition(.blurReplace.animation(.default))
                .id(error.localizedDescription)
            }
          }

          AsyncButton {
            await confirm()
          } label: { isRunning in
            Text(action.title, bundle: .module)
              .frame(maxWidth: .infinity)
              .overlayProgressView(isActive: isRunning) {
                SpinnerView(color: theme.colors.primaryForeground)
              }
          }
          .buttonStyle(.negative())
          .disabled(buttonIsDisabled)
        }
        .padding(24)
      }
      .navigationBarTitleDisplayMode(.inline)
      .preGlassSolidNavBar()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundStyle(theme.colors.primary)
        }

        ToolbarItem(placement: .principal) {
          Text(action.title, bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
    .background(theme.colors.background)
    .presentationBackground(theme.colors.background)
  }
}

extension OrganizationProfileActionConfirmationView {
  @MainActor
  private func confirm() async {
    do {
      switch action {
      case .leave:
        guard let user = clerk.user else { return }
        try await user.leaveOrganization(organizationId: organization.id)
      case .delete:
        try await organization.destroy()
      }

      builtInRouter.dismiss(.exitOrganizationProfile)
      dismiss()
    } catch {
      self.error = error
      ClerkLogger.error(action.logMessage, error: error)
    }
  }
}

extension String {
  fileprivate var confirmationNormalized: String {
    precomposedStringWithCanonicalMapping
      .replacingOccurrences(of: "\u{2018}", with: "'")
      .replacingOccurrences(of: "\u{2019}", with: "'")
      .replacingOccurrences(of: "\u{201B}", with: "'")
      .replacingOccurrences(of: "\u{2032}", with: "'")
      .replacingOccurrences(of: "\u{201C}", with: "\"")
      .replacingOccurrences(of: "\u{201D}", with: "\"")
      .replacingOccurrences(of: "\u{201F}", with: "\"")
      .replacingOccurrences(of: "\u{2033}", with: "\"")
  }
}

enum OrganizationProfileActionConfirmation: Hashable, Identifiable {
  case leave
  case delete

  var id: Self {
    self
  }

  var title: LocalizedStringKey {
    switch self {
    case .leave:
      "Leave organization"
    case .delete:
      "Delete organization"
    }
  }

  var messageLine1: LocalizedStringKey {
    switch self {
    case .leave:
      "Are you sure you want to leave this organization? You will lose access to this organization and its applications."
    case .delete:
      "Are you sure you want to delete this organization?"
    }
  }

  var messageLine2: LocalizedStringKey {
    "This action is permanent and irreversible."
  }

  var logMessage: String {
    switch self {
    case .leave:
      "Failed to leave organization"
    case .delete:
      "Failed to delete organization"
    }
  }
}

#Preview("Leave Organization") {
  OrganizationProfileActionConfirmationView(
    action: .leave,
    organization: .mock
  )
  .environment(\.clerkTheme, .clerk)
  .environment(Clerk.preview())
  .environment(
    OrganizationProfileBuiltInRouter(
      push: { _ in },
      dismissAction: { _ in }
    )
  )
}

#endif
