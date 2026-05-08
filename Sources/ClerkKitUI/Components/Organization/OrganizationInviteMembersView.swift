//
//  OrganizationInviteMembersView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationInviteMembersView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss

  private let cancellationTitle: LocalizedStringKey
  private let onComplete: ((OrganizationInviteMembersCompletion) async -> Void)?

  @State private var roleOptions: [RoleResource] = []
  @State private var emailAddresses: [String] = []
  @State private var selectedRoleKey = ""
  @State private var isLoadingRoles = true
  @State private var hasRoleSetMigration = false
  @State private var error: Error?

  private var canSubmit: Bool {
    !isLoadingRoles
      && !hasRoleSetMigration
      && !emailAddresses.isEmpty
      && roleOptions.contains { $0.key == selectedRoleKey }
  }

  private var selectedRoleName: String {
    roleOptions.first { $0.key == selectedRoleKey }?.name ?? ""
  }

  init(
    cancellationTitle: LocalizedStringKey = "Cancel",
    onComplete: ((OrganizationInviteMembersCompletion) async -> Void)? = nil
  ) {
    self.cancellationTitle = cancellationTitle
    self.onComplete = onComplete
  }

  var body: some View {
    Group {
      if isLoadingRoles {
        SpinnerView()
          .frame(width: 32, height: 32)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        inviteMembersContent
      }
    }
    .presentationBackground(theme.colors.background)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button {
          Task {
            await complete(.cancelled)
          }
        } label: {
          Text(cancellationTitle, bundle: .module)
        }
        .foregroundStyle(theme.colors.primary)
      }

      ToolbarItem(placement: .principal) {
        Text("Invite new members", bundle: .module)
          .font(theme.fonts.headline)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    .onChange(of: emailAddresses) { _, _ in
      error = nil
    }
    .onChange(of: selectedRoleKey) { _, _ in
      error = nil
    }
    .onChange(of: roleOptions.map(\.key), initial: true) { _, _ in
      selectDefaultRoleIfNeeded()
    }
    .task(id: clerk.organization?.id) {
      await loadRoles()
    }
  }

  private var emailField: some View {
    OrganizationInviteEmailAddressField(emailAddresses: $emailAddresses)
  }

  private var inviteMembersContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text(
          "Enter or paste one or more email addresses, separated by spaces or commas.",
          bundle: .module
        )
        .font(theme.fonts.subheadline)
        .foregroundStyle(theme.colors.mutedForeground)
        .fixedSize(horizontal: false, vertical: true)

        VStack(alignment: .leading, spacing: 12) {
          emailField
          rolePicker
        }

        if let error {
          ErrorText(error: error, alignment: .leading)
            .font(theme.fonts.subheadline)
            .transition(.blurReplace.animation(.default))
            .id(error.localizedDescription)
        }

        AsyncButton {
          await submit()
        } label: { isRunning in
          HStack(spacing: 4) {
            Text("Send invitations", bundle: .module)
            Image("icon-triangle-right", bundle: .module)
              .foregroundStyle(theme.colors.primaryForeground)
              .opacity(0.6)
          }
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
  }

  private var rolePicker: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
        Text("Role", bundle: .module)
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.mutedForeground)

        Menu {
          ForEach(roleOptions) { role in
            Button {
              selectedRoleKey = role.key
            } label: {
              Text(verbatim: role.name)
            }
          }
        } label: {
          HStack(spacing: 4) {
            Text(verbatim: selectedRoleName)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.foreground)

            Image(systemName: "chevron.down")
              .font(theme.fonts.caption)
              .foregroundStyle(theme.colors.mutedForeground)
          }
          .padding(.horizontal, 14)
          .frame(height: 32)
          .background(
            theme.colors.background,
            in: .rect(cornerRadius: theme.design.borderRadius)
          )
          .overlay {
            RoundedRectangle(cornerRadius: theme.design.borderRadius)
              .strokeBorder(theme.colors.buttonBorder, lineWidth: 1)
          }
          .shadow(color: theme.colors.buttonBorder, radius: 1, x: 0, y: 1)
        }
        .tint(theme.colors.primary)
        .disabled(roleOptions.isEmpty || hasRoleSetMigration)
      }

      if roleOptions.isEmpty {
        Text("No roles available", bundle: .module)
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.mutedForeground)
      } else if hasRoleSetMigration {
        WarningText(
          "We are updating the available roles. Once that's done, you'll be able to invite members again.",
          bundle: .module
        )
      }
    }
  }

  @MainActor
  private func loadRoles() async {
    guard let organization = clerk.organization else {
      roleOptions = []
      selectedRoleKey = ""
      hasRoleSetMigration = false
      isLoadingRoles = false
      return
    }

    isLoadingRoles = true
    defer { isLoadingRoles = false }

    do {
      let rolesPage = try await organization.getRoles(page: 1, pageSize: 20)
      let roles = rolesPage.data
      if !roles.contains(where: { $0.key == selectedRoleKey }) {
        selectedRoleKey = ""
      }
      roleOptions = roles
      hasRoleSetMigration = rolesPage.hasRoleSetMigration ?? false
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      roleOptions = []
      selectedRoleKey = ""
      hasRoleSetMigration = false
      ClerkLogger.error("Failed to load organization roles for invitations", error: error)
    }
  }

  @MainActor
  private func submit() async {
    error = nil

    let submittedEmailAddresses = emailAddresses
    guard !submittedEmailAddresses.isEmpty, roleOptions.contains(where: { $0.key == selectedRoleKey }) else { return }
    guard let organization = clerk.organization else {
      error = ClerkClientError(message: "Unable to send invitations without an active organization.")
      return
    }

    do {
      try await organization.inviteMembers(emailAddresses: submittedEmailAddresses, role: selectedRoleKey)
      await complete(.sentInvitations)
    } catch {
      self.error = error
    }
  }

  @MainActor
  private func complete(_ completion: OrganizationInviteMembersCompletion) async {
    if let onComplete {
      await onComplete(completion)
    } else {
      dismiss()
    }
  }

  private func selectDefaultRoleIfNeeded() {
    guard selectedRoleKey.isEmpty else { return }

    let defaultRoleKey = clerk.environment?.organizationSettings.domains.defaultRole
    if let defaultRoleKey, roleOptions.contains(where: { $0.key == defaultRoleKey }) {
      selectedRoleKey = defaultRoleKey
    } else if roleOptions.count == 1, let role = roleOptions.first {
      selectedRoleKey = role.key
    }
  }
}

enum OrganizationInviteMembersCompletion {
  case cancelled
  case sentInvitations
}

private struct OrganizationInviteEmailAddressField: View {
  @Environment(\.clerkTheme) private var theme

  @Binding var emailAddresses: [String]

  @State private var emailAddressTags: [String] = []
  @State private var emailAddressDraft = ""
  @FocusState private var emailFieldIsFocused: Bool

  private var emailAddressDelimiters: CharacterSet {
    CharacterSet(charactersIn: ",;\n\t ")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Enter email addresses", bundle: .module)
        .font(theme.fonts.caption)
        .foregroundStyle(theme.colors.mutedForeground)
        .frame(maxWidth: .infinity, alignment: .leading)

      WrappingHStack(alignment: .leading, spacing: 6, lineSpacing: 6) {
        ForEach(emailAddressTags, id: \.self) { emailAddress in
          OrganizationInviteEmailTagView(emailAddress: emailAddress) {
            removeEmailAddressTag(emailAddress)
          }
        }

        TextField("", text: $emailAddressDraft)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.inputForeground)
          .tint(theme.colors.primary)
          .textContentType(.emailAddress)
          .keyboardType(.emailAddress)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)
          .focused($emailFieldIsFocused)
          .frame(minWidth: 24, minHeight: 24, alignment: .leading)
          .onSubmit {
            commitValidEmailAddressDraft()
          }
          .onFirstAppear {
            emailFieldIsFocused = true
          }
      }
      .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .frame(minHeight: 112, alignment: .topLeading)
    .background(
      theme.colors.input,
      in: .rect(cornerRadius: theme.design.borderRadius)
    )
    .clerkFocusedBorder(isFocused: emailFieldIsFocused)
    .contentShape(.rect)
    .onTapGesture {
      emailFieldIsFocused = true
    }
    .onChange(of: emailAddressDraft) { _, newValue in
      handleEmailAddressDraftChange(newValue)
    }
  }

  private func handleEmailAddressDraftChange(_ value: String) {
    guard value.rangeOfCharacter(from: emailAddressDelimiters) != nil else {
      syncEmailAddresses(tags: emailAddressTags, draft: value)
      return
    }

    var nextTags = emailAddressTags
    var invalidFragments: [String] = []

    value
      .components(separatedBy: emailAddressDelimiters)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .forEach { emailAddress in
        if isValidEmailAddress(emailAddress), !nextTags.contains(emailAddress) {
          nextTags.append(emailAddress)
        } else {
          invalidFragments.append(emailAddress)
        }
      }

    let nextDraft = invalidFragments.joined(separator: " ")

    if nextTags != emailAddressTags {
      emailAddressTags = nextTags
    }

    if nextDraft != emailAddressDraft {
      emailAddressDraft = nextDraft
    }

    syncEmailAddresses(tags: nextTags, draft: nextDraft)
  }

  private func commitValidEmailAddressDraft() {
    let trimmedDraft = emailAddressDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard isValidEmailAddress(trimmedDraft), !emailAddressTags.contains(trimmedDraft) else { return }

    let nextTags = emailAddressTags + [trimmedDraft]
    emailAddressTags = nextTags
    emailAddressDraft = ""
    syncEmailAddresses(tags: nextTags, draft: "")
  }

  private func removeEmailAddressTag(_ emailAddress: String) {
    let nextTags = emailAddressTags.filter { $0 != emailAddress }
    emailAddressTags = nextTags
    syncEmailAddresses(tags: nextTags, draft: emailAddressDraft)
    emailFieldIsFocused = true
  }

  private func syncEmailAddresses(tags: [String], draft: String) {
    let submittableEmailAddresses = makeSubmittableEmailAddresses(tags: tags, draft: draft)
    if emailAddresses != submittableEmailAddresses {
      emailAddresses = submittableEmailAddresses
    }
  }

  private func makeSubmittableEmailAddresses(tags: [String], draft: String) -> [String] {
    let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard isValidEmailAddress(trimmedDraft), !tags.contains(trimmedDraft) else {
      return tags
    }

    return tags + [trimmedDraft]
  }

  private func isValidEmailAddress(_ emailAddress: String) -> Bool {
    emailAddress.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
  }
}

private struct OrganizationInviteEmailTagView: View {
  @Environment(\.clerkTheme) private var theme

  let emailAddress: String
  let onRemove: () -> Void

  var body: some View {
    Button {
      onRemove()
    } label: {
      HStack(spacing: 4) {
        Text(verbatim: emailAddress)
          .lineLimit(1)
          .truncationMode(.middle)
          .frame(maxWidth: 220)

        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(theme.colors.mutedForeground)
      }
      .font(theme.fonts.subheadline)
      .foregroundStyle(theme.colors.primary)
      .padding(.leading, 10)
      .padding(.trailing, 8)
      .frame(height: 26)
      .background(theme.colors.muted, in: .rect(cornerRadius: theme.design.borderRadius))
      .overlay {
        RoundedRectangle(cornerRadius: theme.design.borderRadius)
          .strokeBorder(theme.colors.border, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text("Remove email address", bundle: .module))
    .accessibilityValue(Text(verbatim: emailAddress))
  }
}

#endif
