//
//  OrganizationAddDomainView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationAddDomainView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(OrganizationSheetNavigation.self) private var sheetNavigation

  let onDomainChanged: @MainActor () -> Void

  @State private var path: [Destination] = []
  @State private var codeLimiter = CodeLimiter()
  @State private var domainName = ""
  @State private var error: Error?

  private enum Destination: Hashable {
    case verifyEmailAddress(OrganizationDomain)
    case verifyCode(OrganizationDomain, affiliationEmailAddress: String)
  }

  private var organization: Organization? {
    clerk.organization
  }

  private var trimmedDomainName: String {
    domainName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canSubmit: Bool {
    !trimmedDomainName.isEmpty
  }

  var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text(
            "Add the domain to verify. Users with email addresses at this domain can join the organization automatically or request to join.",
            bundle: .module
          )
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.mutedForeground)
          .fixedSize(horizontal: false, vertical: true)

          ClerkTextField(
            "Domain",
            text: $domainName,
            fieldState: error == nil ? .default : .error
          )
          .keyboardType(.URL)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

          if let error {
            ErrorText(error: error, alignment: .leading)
              .font(theme.fonts.subheadline)
              .transition(.blurReplace.animation(.default))
              .id(error.localizedDescription)
          }

          AsyncButton {
            await save()
          } label: { isRunning in
            Text("Save", bundle: .module)
              .frame(maxWidth: .infinity)
              .overlayProgressView(isActive: isRunning) {
                SpinnerView(color: theme.colors.primaryForeground)
              }
          }
          .buttonStyle(.primary())
          .disabled(!canSubmit)
        }
        .padding(24)
      }
      .presentationBackground(theme.colors.background)
      .navigationBarTitleDisplayMode(.inline)
      .preGlassSolidNavBar()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            sheetNavigation.addDomainIsPresented = false
          }
          .foregroundStyle(theme.colors.primary)
        }

        ToolbarItem(placement: .principal) {
          Text("Add domain", bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.foreground)
        }
      }
      .navigationDestination(for: Destination.self) { destination in
        switch destination {
        case let .verifyEmailAddress(domain):
          OrganizationDomainEmailAddressView(domain: domain) { preparedDomain, affiliationEmailAddress in
            path.append(.verifyCode(preparedDomain, affiliationEmailAddress: affiliationEmailAddress))
          }
        case let .verifyCode(domain, affiliationEmailAddress):
          OrganizationDomainVerifyCodeView(
            domain: domain,
            emailAddress: affiliationEmailAddress
          ) {
            onDomainChanged()
            sheetNavigation.addDomainIsPresented = false
          }
        }
      }
    }
    .environment(codeLimiter)
    .onChange(of: domainName) { _, _ in
      error = nil
    }
  }

  @MainActor
  private func save() async {
    guard let organization, canSubmit else { return }

    do {
      let domain = try await organization.createDomain(domainName: trimmedDomainName)
      onDomainChanged()

      if domain.isVerified {
        sheetNavigation.addDomainIsPresented = false
      } else {
        path.append(.verifyEmailAddress(domain))
      }
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to create organization domain", error: error)
    }
  }
}

#endif
