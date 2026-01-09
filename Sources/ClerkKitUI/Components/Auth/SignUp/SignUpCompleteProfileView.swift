//
//  SignUpCompleteProfileView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/23/25.
//

#if os(iOS)

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
    clerk.client?.signUp
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
                ClerkTextField("First name", text: $authState.signUpFirstName)
                  .textContentType(.givenName)
                  .focused($focused, equals: .firstName)
                  .submitLabel(submitLabelFor(.firstName))
                  .onChange(of: authState.signUpFirstName) {
                    updateFocusIfNeeded()
                  }
              }
              if fieldIsMissing(.lastName) {
                ClerkTextField("Last name", text: $authState.signUpLastName)
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
            HStack(spacing: 4) {
              Text("Continue", bundle: .module)
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
          .disabled(continueIsDisabled)
          .simultaneousGesture(TapGesture())
        }

        SecuredByClerkView()
      }
      .padding(16)
    }
    .scrollDismissesKeyboard(.interactively)
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
    .navigationBarTitleDisplayMode(.inline)
    .onFirstAppear {
      focused = firstEmptyMissingField() ?? firstMissingField()
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

  func firstEmptyMissingField() -> Field? {
    Field.allCases.first { field in
      fieldIsMissing(field) && textForField(field).isEmptyTrimmed
    }
  }

  func firstMissingField() -> Field? {
    Field.allCases.first { fieldIsMissing($0) }
  }

  func lastMissingField() -> Field? {
    Field.allCases.last { fieldIsMissing($0) }
  }

  func nextMissingField(after currentField: Field) -> Field? {
    guard let currentIndex = Field.allCases.firstIndex(of: currentField) else {
      return nil
    }

    let fieldsAfterCurrent = Field.allCases.dropFirst(currentIndex + 1)
    return fieldsAfterCurrent.first { fieldIsMissing($0) }
  }
}

// MARK: - Validation

extension SignUpCompleteProfileView {
  func submitLabelFor(_ field: Field) -> SubmitLabel {
    field == lastMissingField() ? .done : .next
  }

  func handleReturnKey() {
    guard let currentField = focused else { return }

    if let nextField = nextMissingField(after: currentField) {
      focused = nextField
    } else {
      focused = nil
    }
  }

  func updateFocusIfNeeded() {
    if focused == nil, let firstEmpty = firstEmptyMissingField() {
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
