//
//  OrganizationDomainEmailAddressView.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct OrganizationDomainEmailAddressView: View {
  @Environment(\.clerkTheme) private var theme

  let domain: OrganizationDomain
  let onCodeSent: @MainActor (OrganizationDomain, String) -> Void

  @State private var emailLocalPart = ""
  @State private var error: Error?

  private var trimmedEmailLocalPart: String {
    emailLocalPart.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var affiliationEmailAddress: String {
    "\(trimmedEmailLocalPart)@\(domain.name)"
  }

  private var canSubmit: Bool {
    !trimmedEmailLocalPart.isEmpty
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text("The domain \(domain.name) needs to be verified via email.", bundle: .module)
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.mutedForeground)
          .fixedSize(horizontal: false, vertical: true)

        VStack(alignment: .leading, spacing: 8) {
          OrganizationDomainEmailAddressField(
            "Verification email address",
            localPart: $emailLocalPart,
            domainName: domain.name,
            fieldState: error == nil ? .default : .error
          )

          if let error {
            ErrorText(error: error, alignment: .leading)
              .font(theme.fonts.subheadline)
              .transition(.blurReplace.animation(.default))
              .id(error.localizedDescription)
          }
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
      ToolbarItem(placement: .principal) {
        Text("Verify domain", bundle: .module)
          .font(theme.fonts.headline)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    .onChange(of: emailLocalPart) { _, newValue in
      error = nil

      let prefix = newValue.split(separator: "@", maxSplits: 1).first.map(String.init) ?? ""
      if prefix.count > 25 {
        emailLocalPart = String(prefix.prefix(25))
      } else if prefix != newValue {
        emailLocalPart = prefix
      }
    }
  }

  @MainActor
  private func save() async {
    guard canSubmit else { return }

    do {
      let preparedDomain = try await domain.sendEmailCode(affiliationEmailAddress: affiliationEmailAddress)
      onCodeSent(preparedDomain, affiliationEmailAddress)
    } catch {
      guard !error.isCancellationError else { return }

      self.error = error
      ClerkLogger.error("Failed to send organization domain verification code", error: error)
    }
  }
}

private struct OrganizationDomainEmailAddressField: View {
  @Environment(\.clerkTheme) private var theme
  @FocusState private var isFocused: Bool

  let titleKey: LocalizedStringKey
  @Binding var localPart: String
  let domainName: String
  let fieldState: ClerkTextField.FieldState

  init(
    _ titleKey: LocalizedStringKey,
    localPart: Binding<String>,
    domainName: String,
    fieldState: ClerkTextField.FieldState = .default
  ) {
    self.titleKey = titleKey
    _localPart = localPart
    self.domainName = domainName
    self.fieldState = fieldState
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(titleKey, bundle: .module)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .font(theme.fonts.caption)
        .foregroundStyle(theme.colors.mutedForeground)
        .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 0) {
        TextField("", text: $localPart)
          .textContentType(.emailAddress)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .focused($isFocused)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.inputForeground)
          .tint(theme.colors.primary)
          .lineLimit(1)

        Text(verbatim: "@\(domainName)")
          .lineLimit(1)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.mutedForeground)
      }
      .frame(minHeight: 22)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
    .frame(minHeight: 56)
    .contentShape(.rect)
    .onTapGesture {
      isFocused = true
    }
    .background(
      theme.colors.input,
      in: .rect(cornerRadius: theme.design.borderRadius)
    )
    .clerkFocusedBorder(
      isFocused: isFocused,
      state: fieldState == .error ? .error : .default
    )
    .onFirstAppear {
      isFocused = true
    }
  }
}

#endif
