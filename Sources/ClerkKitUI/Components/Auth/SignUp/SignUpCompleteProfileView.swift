//
//  SignUpCompleteProfileView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct SignUpCompleteProfileView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation
  @Environment(AuthState.self) private var authState

  @State private var error: Error?
  @State private var safariSheetItem: SafariSheetItem?
  @FocusState private var focused: Field?

  enum Field: CaseIterable {
    case firstName
    case lastName
  }

  var signUp: SignUp? {
    clerk.auth.currentSignUp
  }

  var firstOrLastNameIsMissing: Bool {
    fieldIsMissing(.firstName) || fieldIsMissing(.lastName)
  }

  var legalConsentMissing: Bool {
    signUp?.missingFields.contains(.legalAccepted) ?? false
  }

  var termsUrl: URL? {
    clerk.environment?.displayConfig.termsUrl.flatMap { URL(string: $0) }
  }

  var privacyPolicyUrl: URL? {
    clerk.environment?.displayConfig.privacyPolicyUrl.flatMap { URL(string: $0) }
  }

  var continueIsDisabled: Bool {
    let hasMissingNameFields = (fieldIsMissing(.firstName) && authState.signUpFirstName.isEmptyTrimmed) ||
      (fieldIsMissing(.lastName) && authState.signUpLastName.isEmptyTrimmed)

    let isMissingLegalConsent = legalConsentMissing && !authState.signUpLegalAccepted

    return hasMissingNameFields || isMissingLegalConsent
  }

  var body: some View {
    @Bindable var authState = authState

    ScrollView {
      VStack(spacing: 32) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Profile Details")
          HeaderView(style: .subtitle, text: "Complete your profile")
        }

        VStack(spacing: 24) {
          if firstOrLastNameIsMissing {
            HStack(spacing: 24) {
              if fieldIsMissing(.firstName) {
                ClerkTextField(
                  "First name",
                  text: $authState.signUpFirstName,
                  isEnabled: authState.signUpFirstNameIsEnabled,
                  accessibilityIdentifier: ClerkAccessibilityIdentifiers.Auth.SignUp.completeProfileFirstName
                )
                .textContentType(.givenName)
                .focused($focused, equals: .firstName)
                .submitLabel(submitLabelFor(.firstName))
                .onChange(of: authState.signUpFirstName) {
                  updateFocusIfNeeded()
                }
              }
              if fieldIsMissing(.lastName) {
                ClerkTextField(
                  "Last name",
                  text: $authState.signUpLastName,
                  isEnabled: authState.signUpLastNameIsEnabled,
                  accessibilityIdentifier: ClerkAccessibilityIdentifiers.Auth.SignUp.completeProfileLastName
                )
                .textContentType(.familyName)
                .focused($focused, equals: .lastName)
                .submitLabel(submitLabelFor(.lastName))
                .onChange(of: authState.signUpLastName) {
                  updateFocusIfNeeded()
                }
              }
            }
            .autocorrectionDisabled()
            .onSubmit { handleReturnKey() }
          }

          if legalConsentMissing {
            LegalConsentView(
              isAccepted: $authState.signUpLegalAccepted,
              onTermsTap: termsUrl != nil ? {
                safariSheetItem = SafariSheetItem(url: termsUrl!)
              } : nil,
              onPrivacyTap: privacyPolicyUrl != nil ? {
                safariSheetItem = SafariSheetItem(url: privacyPolicyUrl!)
              } : nil
            )
          }

          AsyncButton {
            await updateSignUp()
          } label: { isRunning in
            ContinueButtonLabelView(isActive: isRunning)
          }
          .buttonStyle(.primary())
          .disabled(continueIsDisabled)
          .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.SignUp.completeProfileContinueButton)
          .simultaneousGesture(TapGesture())
        }

        SecuredByClerkView()
      }
      .padding(16)
    }
    #if os(iOS)
    .scrollDismissesKeyboard(.interactively)
    #endif
    .clerkErrorPresenting($error)
    .sheet(item: $safariSheetItem) { item in
      SafariView(url: item.url)
    }
    .background(theme.colors.background)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Sign up", bundle: .module)
          .font(theme.fonts.headline)
          .foregroundStyle(theme.colors.foreground)
      }
    }
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .onFirstAppear {
      focused = firstEmptyMissingEnabledField() ?? firstMissingEnabledField()
    }
  }
}

// MARK: - Field Helpers

extension SignUpCompleteProfileView {
  func fieldIsMissing(_ field: Field) -> Bool {
    guard let signUp else { return false }
    switch field {
    case .firstName:
      return signUp.missingFields.contains(.firstName)
    case .lastName:
      return signUp.missingFields.contains(.lastName)
    }
  }

  func textForField(_ field: Field) -> String {
    switch field {
    case .firstName:
      authState.signUpFirstName
    case .lastName:
      authState.signUpLastName
    }
  }

  func fieldIsEnabled(_ field: Field) -> Bool {
    switch field {
    case .firstName:
      authState.signUpFirstNameIsEnabled
    case .lastName:
      authState.signUpLastNameIsEnabled
    }
  }

  func firstEmptyMissingEnabledField() -> Field? {
    Field.allCases.first { field in
      fieldIsMissing(field) && fieldIsEnabled(field) && textForField(field).isEmptyTrimmed
    }
  }

  func firstMissingEnabledField() -> Field? {
    Field.allCases.first { fieldIsMissing($0) && fieldIsEnabled($0) }
  }

  func lastMissingEnabledField() -> Field? {
    Field.allCases.last { fieldIsMissing($0) && fieldIsEnabled($0) }
  }

  func nextMissingEnabledField(after currentField: Field) -> Field? {
    guard let currentIndex = Field.allCases.firstIndex(of: currentField) else {
      return nil
    }

    let fieldsAfterCurrent = Field.allCases.dropFirst(currentIndex + 1)
    return fieldsAfterCurrent.first { fieldIsMissing($0) && fieldIsEnabled($0) }
  }
}

// MARK: - Validation

extension SignUpCompleteProfileView {
  func submitLabelFor(_ field: Field) -> SubmitLabel {
    field == lastMissingEnabledField() ? .done : .next
  }

  func handleReturnKey() {
    guard let currentField = focused else { return }

    if let nextField = nextMissingEnabledField(after: currentField) {
      focused = nextField
    } else {
      focused = nil
    }
  }

  func updateFocusIfNeeded() {
    if focused == nil, let firstEmpty = firstEmptyMissingEnabledField() {
      focused = firstEmpty
    }
  }
}

// MARK: - Actions

extension SignUpCompleteProfileView {
  func updateSignUp() async {
    guard var signUp else { return }

    do {
      signUp = try await signUp.update(
        firstName: fieldIsMissing(.firstName) ? authState.signUpFirstName : nil,
        lastName: fieldIsMissing(.lastName) ? authState.signUpLastName : nil,
        legalAccepted: legalConsentMissing ? authState.signUpLegalAccepted : nil
      )
      navigation.setToStepForStatus(signUp: signUp)
    } catch {
      self.error = error
      ClerkLogger.error("Failed to update sign up with profile data", error: error)
    }
  }
}

#Preview {
  SignUpCompleteProfileView()
    .clerkPreview()
    .environment(Clerk.preview { preview in
      var client = Client.mock
      var signUp = SignUp.mock
      signUp.missingFields.append(contentsOf: [
        .firstName,
        .lastName,
        .legalAccepted,
      ])
      client.signUp = signUp
      preview.client = client
    })
    .environment(\.clerkTheme, .clerk)
}

#endif
