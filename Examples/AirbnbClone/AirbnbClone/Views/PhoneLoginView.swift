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

  private let phoneNumberUtility = PhoneNumberUtility()

  @State private var selectedCountry: CountryCodePickerViewController.Country
  @State private var partialFormatter: PartialFormatter
  @State private var displayPhoneNumber = ""
  @State private var e164PhoneNumber = ""
  @State private var showCountryPicker = false
  @FocusState private var isPhoneFieldFocused: Bool

  init(
    showVerification: Binding<Bool>,
    pendingVerification: Binding<PendingVerification?>,
    isLoading: Binding<Bool>,
    errorMessage: Binding<String?>
  ) {
    _showVerification = showVerification
    _pendingVerification = pendingVerification
    _isLoading = isLoading
    _errorMessage = errorMessage

    let utility = PhoneNumberUtility()
    let defaultRegion = Locale.current.region?.identifier ?? "US"
    let defaultCountry = CountryCodePickerViewController.Country(for: defaultRegion, with: utility)
      ?? CountryCodePickerViewController.Country(for: "US", with: utility)!

    _selectedCountry = State(initialValue: defaultCountry)
    _partialFormatter = State(
      initialValue: PartialFormatter(
        utility: utility,
        defaultRegion: defaultCountry.code,
        withPrefix: false
      )
    )
  }

  private var canSubmit: Bool {
    guard !isLoading else { return false }
    let rawDigits = displayPhoneNumber.filter(\.isWholeNumber)
    return rawDigits.count >= 6
  }

  var body: some View {
    VStack(spacing: 0) {
      // Country selector
      Button {
        showCountryPicker = true
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Country/Region")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
            Text("\(selectedCountry.name) (\(selectedCountry.prefix))")
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

      Divider()

      // Phone number input
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Phone number")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

          TextField("", text: $displayPhoneNumber)
            .font(.system(size: 16))
            .keyboardType(.phonePad)
            .focused($isPhoneFieldFocused)
            .onChange(of: displayPhoneNumber) { _, newValue in
              updatePhoneNumber(from: newValue)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(Color(uiColor: .systemGray4), lineWidth: 1)
    )
    .frame(maxWidth: .infinity, alignment: .leading)

    // Disclaimer
    Text("We'll call or text to confirm your number. Standard message and data rates apply.")
      .font(.system(size: 14))
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 6)

    // Continue button
    Button {
      submitPhoneNumber()
    } label: {
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
    .padding(.top, 14)
    .sheet(isPresented: $showCountryPicker) {
      CountryPickerView(selectedCountry: $selectedCountry)
    }
    .onChange(of: selectedCountry.code) { _, newCode in
      partialFormatter.defaultRegion = newCode
      updatePhoneNumber(from: displayPhoneNumber)
    }
  }

  private func updatePhoneNumber(from input: String) {
    // E.164 max is 15 digits (excluding '+')
    let rawDigits = String(input.filter(\.isWholeNumber).prefix(15))
    let formattedDisplay = partialFormatter.formatPartial(rawDigits)

    if displayPhoneNumber != formattedDisplay {
      displayPhoneNumber = formattedDisplay
    }

    if let phoneNumber = try? phoneNumberUtility.parse(rawDigits, withRegion: selectedCountry.code) {
      e164PhoneNumber = phoneNumberUtility.format(phoneNumber, toType: .e164)
      return
    }

    // Fallback: allow example/dev numbers that PhoneNumberKit won't parse/validate.
    // `prefix` includes the "+" (e.g. "+1").
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
