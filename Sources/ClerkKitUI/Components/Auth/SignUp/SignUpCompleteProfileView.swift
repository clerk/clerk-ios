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
  @Environment(AuthState.self) private var authState

  @State private var error: Error?

  @FocusState private var focused: Field?

  enum Field: CaseIterable {
    case firstName
    case lastName
  }

  func fieldIsRequired(_ field: Field) -> Bool {
    guard let signUp else { return false }
    switch field {
    case .firstName:
      signUp.fieldIsRequired(field: "first_name")
    case .lastName:
      signUp.fieldIsRequired(field: "last_name")
    }
  }

  // Get the text for each field
  func textForField(_ field: Field) -> String {
    switch field {
    case .firstName:
      authState.signUpFirstName
    case .lastName:
      authState.signUpLastName
    }
  }

  // Find the first required field that's empty
  func firstEmptyRequiredField() -> Field? {
    Field.allCases.first { field in
      fieldIsRequired(field) && textForField(field).isEmptyTrimmed
    }
  }

  // Get the first required field (fallback)
  func firstRequiredField() -> Field? {
    Field.allCases.first { fieldIsRequired($0) }
  }

  // Get the last required field
  func lastRequiredField() -> Field? {
    Field.allCases.last { fieldIsRequired($0) }
  }

  // Determine the submit label for each field
  func submitLabelFor(_ field: Field) -> SubmitLabel {
    field == lastRequiredField() ? .done : .next
  }

  func nextRequiredField(after currentField: Field) -> Field? {
    guard let currentIndex = Field.allCases.firstIndex(of: currentField) else {
      return nil
    }

    let fieldsAfterCurrent = Field.allCases.dropFirst(currentIndex + 1)
    return fieldsAfterCurrent.first { fieldIsRequired($0) }
  }

  func handleReturnKey() {
    guard let currentField = focused else { return }

    if let nextField = nextRequiredField(after: currentField) {
      focused = nextField
    } else {
      focused = nil
    }
  }

  // Dynamically update focus when text changes
  func updateFocusIfNeeded() {
    // Only update focus if we're not currently focused on a field
    // or if the current field is now filled and there's an empty field to focus on
    if focused == nil, let firstEmpty = firstEmptyRequiredField() {
      focused = firstEmpty
    }
  }

  var signUp: SignUp? {
    clerk.client?.signUp
  }

  var firstOrLastNameIsRequired: Bool {
    fieldIsRequired(.firstName) || fieldIsRequired(.lastName)
  }

  var continueIsDisabled: Bool {
    (fieldIsRequired(.firstName) && authState.signUpFirstName.isEmptyTrimmed) ||
      (fieldIsRequired(.lastName) && authState.signUpLastName.isEmptyTrimmed)
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
          if firstOrLastNameIsRequired {
            HStack(spacing: 24) {
              if fieldIsRequired(.firstName) {
                ClerkTextField("First name", text: $authState.signUpFirstName)
                  .textContentType(.givenName)
                  .focused($focused, equals: .firstName)
                  .submitLabel(submitLabelFor(.firstName))
                  .onChange(of: authState.signUpFirstName) {
                    updateFocusIfNeeded()
                  }
              }
              if fieldIsRequired(.lastName) {
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
      focused = firstEmptyRequiredField() ?? firstRequiredField()
    }
  }
}

extension SignUpCompleteProfileView {
  func updateSignUp() async {
    guard var signUp else { return }

    do {
      signUp = try await signUp.update(
        params: .init(
          firstName: authState.signUpFirstName,
          lastName: authState.signUpLastName
        )
      )
      authState.setToStepForStatus(signUp: signUp)
    } catch {
      self.error = error
      ClerkLogger.error("Failed to update sign up with profile data", error: error)
    }
  }
}

#Preview {
  SignUpCompleteProfileView()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#endif
