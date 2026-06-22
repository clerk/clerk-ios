//
//  ClerkPhoneNumberField.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import PhoneNumberKit
import SwiftUI

extension ClerkPhoneNumberField {
  @Observable
  @MainActor
  final class PhoneNumberModel {
    private let utility = PhoneNumberUtility()
    let partialFormatter: PartialFormatter

    let defaultCountry: ClerkPhoneCountry
    var currentCountry: ClerkPhoneCountry {
      didSet {
        partialFormatter.defaultRegion = currentCountry.code
      }
    }

    init() {
      let resolvedDefaultCountry = Self.defaultCountry(using: utility) ?? utility.allCountries.first

      guard let defaultCountry = resolvedDefaultCountry else {
        preconditionFailure("PhoneNumberKit returned no supported countries")
      }

      self.defaultCountry = defaultCountry
      currentCountry = defaultCountry
      partialFormatter = .init(
        utility: utility,
        defaultRegion: defaultCountry.code,
        withPrefix: false
      )
    }

    private static func defaultCountry(using utility: PhoneNumberUtility) -> ClerkPhoneCountry? {
      [
        PhoneNumberUtility.defaultRegionCode(),
        Locale.current.region?.identifier,
        Locale.autoupdatingCurrent.region?.identifier,
        "US",
      ]
      .compactMap(\.self)
      .compactMap { ClerkPhoneCountry(for: $0, with: utility) }
      .first
    }

    var allCountriesExceptDefault: [ClerkPhoneCountry] {
      utility.allCountries.filter { country in
        country.code != defaultCountry.code
      }
    }

    func stringForCountry(_ country: ClerkPhoneCountry) -> String {
      "\(country.flag) \(country.name) \(country.prefix)"
    }

    var exampleNumber: String {
      utility.getFormattedExampleNumber(
        forCountry: currentCountry.code,
        withFormat: .national,
        withPrefix: false
      ) ?? ""
    }

    func formattedText(for text: String) -> (displayText: String, dataText: String) {
      if let phoneNumber = try? utility.parse(text, withRegion: currentCountry.code) {
        updateCurrentCountry(for: phoneNumber)
        return (
          utility.format(phoneNumber, toType: .national),
          utility.format(phoneNumber, toType: .e164)
        )
      }

      let rawText = text.filter(\.isWholeNumber)
      return (
        partialFormatter.formatPartial(rawText),
        rawText
      )
    }

    private func updateCurrentCountry(for phoneNumber: PhoneNumber) {
      let countryCode = phoneNumber.regionID ?? utility.mainCountry(forCode: phoneNumber.countryCode)
      guard
        let countryCode,
        let country = ClerkPhoneCountry(for: countryCode, with: utility)
      else { return }

      currentCountry = country
    }
  }
}

struct ClerkPhoneNumberField: View {
  @Environment(\.clerkTheme) private var theme
  @State private var phoneNumberModel = PhoneNumberModel()
  @State private var reservedHeight: CGFloat?
  @State var displayText = ""
  @FocusState private var isFocused: Bool

  enum FieldState {
    case `default`, error
  }

  let titleKey: LocalizedStringKey
  @Binding var text: String
  let fieldState: FieldState
  let isEnabled: Bool
  let accessibilityIdentifier: String

  init(
    _ titleKey: LocalizedStringKey,
    text: Binding<String>,
    fieldState: FieldState = .default,
    isEnabled: Bool = true,
    accessibilityIdentifier: String = ""
  ) {
    self.titleKey = titleKey
    _text = text
    self.fieldState = fieldState
    self.isEnabled = isEnabled
    self.accessibilityIdentifier = accessibilityIdentifier
  }

  var isFocusedOrFilled: Bool {
    isFocused || !text.isEmpty
  }

  var offsetAmount: CGFloat {
    guard let reservedHeight else { return 0 }
    return reservedHeight * 0.333
  }

  private func textDidUpdate(text: String) {
    let formattedText = phoneNumberModel.formattedText(for: text)
    displayText = formattedText.displayText
    self.text = formattedText.dataText
  }

  var countrySelector: some View {
    Menu {
      Section("Default") {
        Button {
          phoneNumberModel.currentCountry = phoneNumberModel.defaultCountry
          textDidUpdate(text: displayText)
        } label: {
          Text(phoneNumberModel.stringForCountry(phoneNumberModel.defaultCountry))
            .lineLimit(1)
        }
      }

      Section("International") {
        ForEach(phoneNumberModel.allCountriesExceptDefault, id: \.code) { country in
          Button {
            phoneNumberModel.currentCountry = country
            textDidUpdate(text: displayText)
          } label: {
            Text(phoneNumberModel.stringForCountry(country))
              .lineLimit(1)
          }
        }
      }
    } label: {
      HStack(spacing: 4) {
        Text(verbatim: "\(phoneNumberModel.currentCountry.flag) \(phoneNumberModel.currentCountry.code)")
          .font(theme.fonts.footnote)
          .foregroundStyle(theme.colors.foreground)
          .monospaced()

        Image("icon-up-down", bundle: .module)
          .foregroundStyle(theme.colors.mutedForeground)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 13)
      .background(theme.colors.muted)
      .clipShape(.rect(cornerRadius: theme.design.borderRadius))
      .contentShape(.rect(cornerRadius: theme.design.borderRadius))
    }
  }

  var body: some View {
    HStack(spacing: 8) {
      countrySelector

      ZStack(alignment: .leading) {
        VStack(alignment: .leading, spacing: 2) {
          Text(titleKey, bundle: .module)
            .lineLimit(1)
            .font(theme.fonts.caption)
            .foregroundStyle(theme.colors.foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(0)

          HStack(spacing: 4) {
            if isFocusedOrFilled {
              Text(phoneNumberModel.currentCountry.prefix)
                .transition(
                  .asymmetric(
                    insertion: .opacity.animation(.default.delay(0.1)),
                    removal: .opacity.animation(nil)
                  )
                )
            }

            TextField("", text: $displayText)
              .focused($isFocused)
              .textContentType(.telephoneNumber)
              #if os(iOS)
              .keyboardType(.numberPad)
              #endif
              .tint(theme.colors.primary)
              .animation(.default.delay(0.2)) {
                $0.opacity(isFocusedOrFilled ? 1 : 0)
              }
              .onChange(of: displayText) { _, newValue in
                textDidUpdate(text: newValue)
              }
          }
          .lineLimit(1)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.inputForeground)
          .frame(minHeight: 22)
        }
        .onGeometryChange(for: CGFloat.self) { geometry in
          geometry.size.height
        } action: { newValue in
          reservedHeight = newValue
        }

        Text(titleKey, bundle: .module)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.mutedForeground)
          .frame(maxWidth: .infinity, alignment: .leading)
          .allowsHitTesting(false)
          .offset(y: isFocusedOrFilled ? -offsetAmount : 0)
          .scaleEffect(isFocusedOrFilled ? (12 / 17) : 1, anchor: .topLeading)
          .animation(.default, value: isFocusedOrFilled)
      }
      .accessibilityIdentifier(accessibilityIdentifier)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 6)
    .frame(minHeight: 56)
    .contentShape(.rect)
    .onTapGesture {
      isFocused = true
    }
    .disabled(!isEnabled)
    .background(
      theme.colors.input,
      in: .rect(cornerRadius: theme.design.borderRadius)
    )
    .clerkFocusedBorder(
      isFocused: isFocused,
      state: fieldState == .error ? .error : .default
    )
    .onAppear {
      textDidUpdate(text: text)
    }
  }
}

#Preview {
  @Previewable @State var emptyEmail = ""
  @Previewable @State var filledEmail = "5555550100"

  VStack(spacing: 20) {
    ClerkPhoneNumberField("Enter your phone number", text: $emptyEmail)
    ClerkPhoneNumberField("Enter your phone number", text: $filledEmail)
  }
  .padding()
}

#endif
