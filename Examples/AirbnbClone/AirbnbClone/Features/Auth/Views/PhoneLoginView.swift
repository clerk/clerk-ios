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
  @FocusState private var isPhoneFieldFocused: Bool

  private static var defaultCountry: CountryCodePickerViewController.Country {
    let regionCode = Locale.current.region?.identifier ?? "US"
    return CountryCodePickerViewController.Country(for: regionCode, with: phoneNumberUtility)
      ?? CountryCodePickerViewController.Country(for: "US", with: phoneNumberUtility)!
  }

  private var canSubmit: Bool {
    guard !isLoading else { return false }
    let rawDigits = displayPhoneNumber.filter(\.isWholeNumber)
    return rawDigits.count >= 6
  }

  var body: some View {
    VStack(spacing: 0) {
      PhoneInputContainer(
        selectedCountry: selectedCountry,
        displayPhoneNumber: $displayPhoneNumber,
        isPhoneFieldFocused: $isPhoneFieldFocused,
        onCountryTap: {
          dismissKeyboard()
          showCountryPicker = true
        },
        onPhoneNumberChange: updatePhoneNumber
      )

      PhoneDisclaimer()
        .padding(.top, 6)

      PhoneContinueButton(
        canSubmit: canSubmit,
        isLoading: isLoading
      ) {
        dismissKeyboard()
        submitPhoneNumber()
      }
      .padding(.top, 14)
    }
    .sheet(isPresented: $showCountryPicker) {
      CountryPickerView(selectedCountry: $selectedCountry)
    }
    .onChange(of: selectedCountry.code) { _, newCode in
      partialFormatter.defaultRegion = newCode
      updatePhoneNumber(from: displayPhoneNumber)
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

// MARK: - PhoneInputContainer

private struct PhoneInputContainer: View {
  let selectedCountry: CountryCodePickerViewController.Country
  @Binding var displayPhoneNumber: String
  var isPhoneFieldFocused: FocusState<Bool>.Binding
  let onCountryTap: () -> Void
  let onPhoneNumberChange: (String) -> Void

  var body: some View {
    VStack(spacing: 0) {
      CountrySelectorRow(
        country: selectedCountry,
        onTap: onCountryTap
      )

      Divider()

      PhoneNumberInputRow(
        displayPhoneNumber: $displayPhoneNumber,
        isFocused: isPhoneFieldFocused,
        onPhoneNumberChange: onPhoneNumberChange
      )
    }
    .background(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(Color(uiColor: .systemGray4), lineWidth: 1)
    )
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - CountrySelectorRow

private struct CountrySelectorRow: View {
  let country: CountryCodePickerViewController.Country
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Country/Region")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
          Text("\(country.name) (\(country.prefix))")
            .font(.system(size: 16))
            .foregroundStyle(.primary)
        }

        Spacer()

        Image(systemName: "chevron.down")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16)
      .frame(height: 56)
      .contentShape(.rect)
      .frame(maxWidth: .infinity, alignment: .leading)
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
    HStack {
      VStack(alignment: .leading, spacing: 4) {
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
      .frame(height: 56)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// MARK: - PhoneDisclaimer

private struct PhoneDisclaimer: View {
  var body: some View {
    Text("We'll call or text to confirm your number. Standard message and data rates apply.")
      .font(.system(size: 14))
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - PhoneContinueButton

private struct PhoneContinueButton: View {
  let canSubmit: Bool
  let isLoading: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text("Continue")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.white)
        .opacity(isLoading ? 0 : 1)
        .overlay {
          if isLoading {
            LoadingDotsView(color: .white)
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
          canSubmit
            ? Color(red: 0.87, green: 0.0, blue: 0.35)
            : Color(uiColor: .systemGray4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .disabled(!canSubmit)
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
