//
//  OrganizationDomainDeleteConfirmationView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationDomainDeleteConfirmationView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  let domain: OrganizationDomain
  let onDomainDeleted: @MainActor (OrganizationDomain) -> Void

  @State private var error: Error?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          VStack(alignment: .leading, spacing: 8) {
            Text("The email domain \(domain.name) will be removed.", bundle: .module)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.danger)
              .fixedSize(horizontal: false, vertical: true)

            Text("Users won't be able to join the organization automatically after this.", bundle: .module)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.mutedForeground)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          if let error {
            ErrorText(error: error, alignment: .leading)
              .font(theme.fonts.subheadline)
              .transition(.blurReplace.animation(.default))
              .id(error.localizedDescription)
          }

          AsyncButton {
            await deleteDomain()
          } label: { isRunning in
            Text("Remove", bundle: .module)
              .frame(maxWidth: .infinity)
              .overlayProgressView(isActive: isRunning) {
                SpinnerView(color: theme.colors.primaryForeground)
              }
          }
          .buttonStyle(.negative())
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
          Text("Remove domain", bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
    .background(theme.colors.background)
    .presentationBackground(theme.colors.background)
  }
}

extension OrganizationDomainDeleteConfirmationView {
  @MainActor
  private func deleteDomain() async {
    do {
      try await domain.delete()
      onDomainDeleted(domain)
      dismiss()
    } catch {
      self.error = error
      ClerkLogger.error("Failed to remove organization domain", error: error)
    }
  }
}

#Preview {
  OrganizationDomainDeleteConfirmationView(domain: .mock) { _ in }
    .environment(\.clerkTheme, .clerk)
}

#endif
