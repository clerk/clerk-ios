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

  @Binding var showVerification: Bool
  @Binding var pendingVerification: PendingVerification?
  @Binding var isLoading: Bool
  @Binding var errorMessage: String?

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

      PhoneValidationError(isVisible: showValidationError)
        .padding(.top, 8)

      PhoneDisclaimer()
        .padding(.top, showValidationError ? 4 : 8)

      PhoneContinueButton(isLoading: isLoading) {
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
      do {
        let signIn = try await clerk.auth.signInWithPhoneCode(phoneNumber: e164PhoneNumber)
        pendingVerification = .signIn(signIn)
        showVerification = true
      } catch {
        if let apiError = error as? ClerkAPIError,
           ["form_identifier_not_found", "invitation_account_not_exists"].contains(apiError.code)
        {
          do {
            let signUp = try await clerk.auth.signUp(phoneNumber: e164PhoneNumber)
            let prepared = try await signUp.sendPhoneCode()
            pendingVerification = .signUp(prepared, .phone)
            showVerification = true
          } catch {
            errorMessage = error.localizedDescription
          }
        } else {
          errorMessage = error.localizedDescription
        }
      }
      isLoading = false
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
      if isFocused {
        withAnimation(.easeInOut(duration: 0.2)) {
          focusedField = .phone
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

// MARK: - PhoneValidationError

private struct PhoneValidationError: View {
  let isVisible: Bool

  var body: some View {
    if isVisible {
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.circle.fill")
          .font(.system(size: 14))
        Text("Please enter a valid phone number")
          .font(.system(size: 14))
      }
      .foregroundStyle(Color(red: 0.76, green: 0.15, blue: 0.18))
      .frame(maxWidth: .infinity, alignment: .leading)
      .transition(.opacity)
    }
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

// MARK: - PhoneContinueButton

private struct PhoneContinueButton: View {
  let isLoading: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text("Continue")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white)
        .opacity(isLoading ? 0 : 1)
        .overlay {
          if isLoading {
            LoadingDotsView(color: .white)
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color(red: 0.87, green: 0.0, blue: 0.35))
        .clipShape(.rect(cornerRadius: 10))
    }
    .disabled(isLoading)
  }
}

// MARK: - Preview

#Preview {
  PhoneLoginView(
    showVerification: .constant(false),
    pendingVerification: .constant(nil),
    isLoading: .constant(false),
    errorMessage: .constant(nil)
  )
  .padding()
  .environment(Clerk.preview())
}
