//
//  PhoneLoginView.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import PhoneNumberKit
import SwiftUI

struct PhoneLoginView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(Router.self) private var router
  @Environment(\.otpLoginMode) private var otpLoginMode

  @State private var selectedCountry = defaultCountry
  @State private var partialFormatter = PartialFormatter(
    utility: phoneNumberUtility,
    defaultRegion: defaultCountry.code,
    withPrefix: false
  )
  @State private var displayPhoneNumber = ""
  @State private var e164PhoneNumber = ""
  @State private var showCountryPicker = false
  @State private var showValidationError = false
  @State private var isLoading = false
  @State private var errorMessage: String?
  @FocusState private var isPhoneFieldFocused: Bool

  private static var defaultCountry: CountryCodePickerViewController.Country {
    let regionCode = Locale.current.region?.identifier ?? "US"
    return CountryCodePickerViewController.Country(for: regionCode, with: phoneNumberUtility)
      ?? CountryCodePickerViewController.Country(for: "US", with: phoneNumberUtility)!
  }

  private var isValidPhoneNumber: Bool {
    let rawDigits = displayPhoneNumber.filter(\.isWholeNumber)
    return rawDigits.count >= 6
  }

  var body: some View {
    VStack(spacing: 0) {
      PhoneInputContainer(
        selectedCountry: selectedCountry,
        displayPhoneNumber: $displayPhoneNumber,
        isPhoneFieldFocused: $isPhoneFieldFocused,
        showCountryPicker: showCountryPicker,
        onCountryTap: {
          dismissKeyboard()
          showCountryPicker = true
        },
        onPhoneNumberChange: updatePhoneNumber
      )

      ValidationError(message: "Please enter a valid phone number", isVisible: showValidationError)
        .padding(.top, 8)

      ErrorMessage(message: errorMessage)
        .padding(.top, 8)

      PhoneDisclaimer()
        .padding(.top, showValidationError ? 4 : 8)

      ContinueButton(isLoading: isLoading) {
        dismissKeyboard()
        if isValidPhoneNumber {
          showValidationError = false
          submitPhoneNumber()
        } else {
          showValidationError = true
        }
      }
      .padding(.top, showValidationError ? 10 : 14)
    }
    .animation(.default, value: showValidationError)
    .animation(.default, value: errorMessage)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") {
          isPhoneFieldFocused = false
        }
      }
    }
    .sheet(isPresented: $showCountryPicker) {
      CountryPickerView(selectedCountry: $selectedCountry)
    }
    .onChange(of: selectedCountry.code) { _, newCode in
      partialFormatter.defaultRegion = newCode
      updatePhoneNumber(from: displayPhoneNumber)
    }
    .onChange(of: displayPhoneNumber) {
      if showValidationError, isValidPhoneNumber {
        showValidationError = false
      }
    }
  }
}

// MARK: - Actions

extension PhoneLoginView {
  private func updatePhoneNumber(from input: String) {
    let rawDigits = String(input.filter(\.isWholeNumber).prefix(15))
    let formattedDisplay = partialFormatter.formatPartial(rawDigits)

    if displayPhoneNumber != formattedDisplay {
      displayPhoneNumber = formattedDisplay
    }

    if let phoneNumber = try? phoneNumberUtility.parse(rawDigits, withRegion: selectedCountry.code) {
      e164PhoneNumber = phoneNumberUtility.format(phoneNumber, toType: .e164)
      return
    }

    e164PhoneNumber = rawDigits.isEmpty ? "" : "\(selectedCountry.prefix)\(rawDigits)"
  }

  private func submitPhoneNumber() {
    Task {
      isLoading = true
      errorMessage = nil
      defer { isLoading = false }

      do {
        // Try sign up first
        try await clerk.auth.signUp(phoneNumber: e164PhoneNumber)
        router.authPath.append(
          AuthDestination.finishSigningUp(
            identifierValue: e164PhoneNumber,
            loginMode: .signUp(method: .phone)
          )
        )
      } catch {
        // If sign up fails, try sign in
        do {
          try await clerk.auth.signInWithPhoneCode(phoneNumber: e164PhoneNumber)
          otpLoginMode.wrappedValue = .signIn(method: .phone)
          router.showOTPVerification = true
        } catch {
          errorMessage = error.localizedDescription
        }
      }
    }
  }
}

// MARK: - PhoneInputFocus

private enum PhoneInputFocus: Hashable {
  case country
  case phone
}

// MARK: - PhoneInputContainer

private struct PhoneInputContainer: View {
  let selectedCountry: CountryCodePickerViewController.Country
  @Binding var displayPhoneNumber: String
  var isPhoneFieldFocused: FocusState<Bool>.Binding
  let showCountryPicker: Bool
  let onCountryTap: () -> Void
  let onPhoneNumberChange: (String) -> Void

  @State private var focusedField: PhoneInputFocus?
  @Namespace private var animation

  var body: some View {
    VStack(spacing: 0) {
      CountrySelectorRow(
        country: selectedCountry,
        onTap: {
          withAnimation(.easeInOut(duration: 0.2)) {
            focusedField = .country
          }
          onCountryTap()
        }
      )
      .background {
        if focusedField == .country {
          RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color(uiColor: .label), lineWidth: 2)
            .matchedGeometryEffect(id: "highlight", in: animation)
        }
      }

      if focusedField == nil {
        Divider()
      }

      PhoneNumberInputRow(
        displayPhoneNumber: $displayPhoneNumber,
        isFocused: isPhoneFieldFocused,
        onPhoneNumberChange: onPhoneNumberChange
      )
      .background {
        if focusedField == .phone {
          RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color(uiColor: .label), lineWidth: 2)
            .matchedGeometryEffect(id: "highlight", in: animation)
        }
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
    )
    .frame(maxWidth: .infinity, alignment: .leading)
    .onChange(of: isPhoneFieldFocused.wrappedValue) { _, isFocused in
      withAnimation(.easeInOut(duration: 0.2)) {
        if isFocused {
          focusedField = .phone
        } else if focusedField == .phone {
          focusedField = nil
        }
      }
    }
    .onChange(of: showCountryPicker) { _, isShowing in
      if isShowing {
        withAnimation(.easeInOut(duration: 0.2)) {
          focusedField = .country
        }
      }
    }
  }
}

// MARK: - CountrySelectorRow

private struct CountrySelectorRow: View {
  let country: CountryCodePickerViewController.Country
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Country/Region")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
          Text("\(country.name) (\(country.prefix))")
            .font(.system(size: 16))
            .foregroundStyle(Color(uiColor: .label))
        }

        Spacer()

        Image(systemName: "chevron.down")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color(uiColor: .label))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - PhoneNumberInputRow

private struct PhoneNumberInputRow: View {
  @Binding var displayPhoneNumber: String
  var isFocused: FocusState<Bool>.Binding
  let onPhoneNumberChange: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("Phone number")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)

      TextField("", text: $displayPhoneNumber)
        .font(.system(size: 16))
        .keyboardType(.phonePad)
        .focused(isFocused)
        .onChange(of: displayPhoneNumber) { _, newValue in
          onPhoneNumberChange(newValue)
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - PhoneDisclaimer

private struct PhoneDisclaimer: View {
  var body: some View {
    Text("We'll call or text to confirm your number. Standard message and data rates apply.")
      .font(.system(size: 14))
      .foregroundStyle(Color(uiColor: .label))
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Preview

#Preview {
  PhoneLoginView()
    .padding()
    .environment(Clerk.preview())
    .environment(Router())
}
