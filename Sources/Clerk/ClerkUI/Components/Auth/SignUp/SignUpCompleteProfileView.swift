//
//  SignUpCompleteProfileView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/23/25.
//

#if os(iOS)

  import SwiftUI

  struct SignUpCompleteProfileView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.authState) private var authState

    @State private var error: Error?

    @FocusState private var focused: Field?

    enum Field: CaseIterable {
      case firstName
      case lastName
    }

    func fieldIsEnabled(_ field: Field) -> Bool {
      switch field {
      case .firstName:
        clerk.environment.firstNameIsEnabled
      case .lastName:
        clerk.environment.lastNameIsEnabled
      }
    }

    // Get the text for each field
    func textForField(_ field: Field) -> String {
      switch field {
      case .firstName:
        return authState.signUpFirstName
      case .lastName:
        return authState.signUpLastName
      }
    }

    // Find the first enabled field that's empty
    func firstEmptyEnabledField() -> Field? {
      return Field.allCases.first { field in
        fieldIsEnabled(field) && textForField(field).isEmptyTrimmed
      }
    }

    // Get the first enabled field (fallback)
    func firstEnabledField() -> Field? {
      return Field.allCases.first { fieldIsEnabled($0) }
    }

    // Get the last enabled field
    func lastEnabledField() -> Field? {
      return Field.allCases.last { fieldIsEnabled($0) }
    }

    // Determine the submit label for each field
    func submitLabelFor(_ field: Field) -> SubmitLabel {
      return field == lastEnabledField() ? .done : .next
    }

    func nextEnabledField(after currentField: Field) -> Field? {
      guard let currentIndex = Field.allCases.firstIndex(of: currentField) else {
        return nil
      }

      let fieldsAfterCurrent = Field.allCases.dropFirst(currentIndex + 1)
      return fieldsAfterCurrent.first { fieldIsEnabled($0) }
    }

    func handleReturnKey() {
      guard let currentField = focused else { return }

      if let nextField = nextEnabledField(after: currentField) {
        focused = nextField
      } else {
        focused = nil
      }
    }

    // Dynamically update focus when text changes
    func updateFocusIfNeeded() {
      // Only update focus if we're not currently focused on a field
      // or if the current field is now filled and there's an empty field to focus on
      if focused == nil, let firstEmpty = firstEmptyEnabledField() {
        focused = firstEmpty
      }
    }

    var signUp: SignUp? {
      clerk.client?.signUp
    }

    var firstOrLastNameIsEnabled: Bool {
      fieldIsEnabled(.firstName) || fieldIsEnabled(.lastName)
    }

    var continueIsDisabled: Bool {
      authState.signUpFirstName.isEmptyTrimmed || authState.signUpLastName.isEmptyTrimmed
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
            if firstOrLastNameIsEnabled {
              HStack(spacing: 24) {
                if fieldIsEnabled(.firstName) {
                  ClerkTextField("First name", text: $authState.signUpFirstName)
                    .textContentType(.givenName)
                    .focused($focused, equals: .firstName)
                    .submitLabel(submitLabelFor(.firstName))
                    .onChange(of: authState.signUpFirstName) {
                      updateFocusIfNeeded()
                    }
                }
                if fieldIsEnabled(.lastName) {
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
        focused = firstEmptyEnabledField() ?? firstEnabledField()
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
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
