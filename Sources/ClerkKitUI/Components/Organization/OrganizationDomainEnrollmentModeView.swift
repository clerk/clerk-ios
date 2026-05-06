//
//  OrganizationDomainEnrollmentModeView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationDomainEnrollmentModeView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  let onDomainChanged: @MainActor (OrganizationDomain) -> Void

  @State private var domain: OrganizationDomain
  @State private var selectedMode: OrganizationDomain.EnrollmentMode
  @State private var deletePending = false
  @State private var error: Error?

  init(
    domain: OrganizationDomain,
    onDomainChanged: @escaping @MainActor (OrganizationDomain) -> Void
  ) {
    _domain = State(initialValue: domain)
    _selectedMode = State(initialValue: domain.enrollmentModeType)
    self.onDomainChanged = onDomainChanged
  }

  private var enrollmentModeOptions: [OrganizationDomainEnrollmentModeOption] {
    OrganizationDomainEnrollmentModeOption.options(
      for: clerk.environment?.organizationSettings.domains.enrollmentModes ?? []
    )
  }

  private var showsDeletePendingToggle: Bool {
    selectedMode == .manualInvitation
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text("Choose how users from this domain can join the organization.", bundle: .module)
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.mutedForeground)
          .fixedSize(horizontal: false, vertical: true)

        VStack(spacing: 12) {
          ForEach(enrollmentModeOptions) { option in
            OrganizationDomainEnrollmentModeRow(
              option: option,
              isSelected: selectedMode == option.mode
            ) {
              selectedMode = option.mode
              if selectedMode != .manualInvitation {
                deletePending = false
              }
              error = nil
            }
          }
        }

        if showsDeletePendingToggle {
          Toggle(isOn: $deletePending) {
            Text("Delete pending invitations and suggestions", bundle: .module)
          }
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.foreground)
          .tint(theme.colors.primary)
          .frame(minHeight: 22)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(theme.colors.muted, in: .rect(cornerRadius: theme.design.borderRadius))
        }

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
      }
      .padding(24)
    }
    .background(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Update \(domain.name)", bundle: .module)
          .font(theme.fonts.headline)
          .fontWeight(.semibold)
          .foregroundStyle(theme.colors.foreground)
      }
    }
  }
}

// MARK: - Subviews

private struct OrganizationDomainEnrollmentModeRow: View {
  @Environment(\.clerkTheme) private var theme

  let option: OrganizationDomainEnrollmentModeOption
  let isSelected: Bool
  let onSelect: () -> Void

  var body: some View {
    Button {
      onSelect()
    } label: {
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
          .font(theme.fonts.body)
          .foregroundStyle(isSelected ? theme.colors.primary : theme.colors.inputBorder)
          .frame(width: 22, height: 22)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text(option.title, bundle: .module)
            .font(theme.fonts.body)
            .fontWeight(.semibold)
            .foregroundStyle(theme.colors.foreground)
            .fixedSize(horizontal: false, vertical: true)

          Text(option.description, bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.leading, 12)
      .padding(.trailing, 16)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        theme.colors.input,
        in: .rect(cornerRadius: theme.design.borderRadius)
      )
      .overlay {
        RoundedRectangle(cornerRadius: theme.design.borderRadius)
          .strokeBorder(theme.colors.inputBorder, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityValue(isSelected ? Text("Selected", bundle: .module) : Text(""))
  }
}

// MARK: - Actions

extension OrganizationDomainEnrollmentModeView {
  @MainActor
  private func save() async {
    do {
      let updatedDomain = try await domain.updateEnrollmentMode(
        selectedMode,
        deletePending: showsDeletePendingToggle ? deletePending : nil
      )
      domain = updatedDomain
      onDomainChanged(updatedDomain)
      dismiss()
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to update organization domain enrollment mode", error: error)
    }
  }
}

// MARK: - Types

private struct OrganizationDomainEnrollmentModeOption: Identifiable {
  let mode: OrganizationDomain.EnrollmentMode
  let title: LocalizedStringKey
  let description: LocalizedStringKey

  var id: String {
    mode.rawValue
  }

  static func options(for rawEnrollmentModes: [String]) -> [Self] {
    allOptions.filter { option in
      rawEnrollmentModes.contains(option.mode.rawValue)
    }
  }

  private static var allOptions: [Self] {
    [
      .init(
        mode: .manualInvitation,
        title: "No automatic enrollment",
        description: "Users can only be invited manually to the organization."
      ),
      .init(
        mode: .automaticInvitation,
        title: "Automatic invitations",
        description: "Users are automatically invited to join the organization when they sign-up and can join anytime."
      ),
      .init(
        mode: .automaticSuggestion,
        title: "Automatic suggestions",
        description: "Users receive a suggestion to request to join, but must be approved by an admin before they are able to join the organization."
      ),
    ]
  }
}

#Preview("Domain Enrollment Mode") {
  NavigationStack {
    OrganizationDomainEnrollmentModeView(
      domain: {
        var domain = OrganizationDomain.mock
        domain.name = "clerky.com"
        domain.enrollmentMode = OrganizationDomain.EnrollmentMode.manualInvitation.rawValue
        domain.verification.status = "verified"
        return domain
      }()
    ) { _ in }
      .environment(
        Clerk.preview { preview in
          var environment = Clerk.Environment.mock
          environment.organizationSettings.domains.enrollmentModes = [
            OrganizationDomain.EnrollmentMode.manualInvitation.rawValue,
            OrganizationDomain.EnrollmentMode.automaticInvitation.rawValue,
            OrganizationDomain.EnrollmentMode.automaticSuggestion.rawValue,
          ]
          preview.environment = environment
        }
      )
  }
}

#endif
