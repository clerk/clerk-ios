//
//  ClerkPhoneNumberField.swift
//  Clerk
//
//  Created by Mike Pitre on 4/10/25.
//

#if canImport(SwiftUI)

  import Factory
  import PhoneNumberKit
  import SwiftUI

  extension ClerkPhoneNumberField {
    @Observable
    @MainActor
    final class PhoneNumberModel {

      let textField: PhoneNumberTextField
      private let utility = Container.shared.phoneNumberUtility()

      init() {
        self.textField = .init(utility: utility)
      }

      var defaultCountry: CountryCodePickerViewController.Country? {
        .init(for: textField.defaultRegion, with: utility)
      }

      var currentCountry: CountryCodePickerViewController.Country? {
        .init(for: textField.currentRegion, with: utility)
      }

      func setCountry(_ country: CountryCodePickerViewController.Country) {
        textField.partialFormatter.defaultRegion = country.code
      }

      var allCountriesExceptDefault: [CountryCodePickerViewController.Country] {
        utility.allCountries.filter { country in
          country.code != defaultCountry?.code
        }
      }

      func stringForCountry(_ country: CountryCodePickerViewController.Country) -> String {
        "\(country.flag) \(country.name) \(country.prefix)"
      }

      var exampleNumber: String {
        utility.getFormattedExampleNumber(
          forCountry: textField.currentRegion,
          withFormat: .national,
          withPrefix: false
        ) ?? ""
      }

      func phoneNumberFormattedForDisplay() -> String {
        if let phoneNumber = textField.phoneNumber {
          return utility.format(phoneNumber, toType: .national, withPrefix: false)
        } else {
          return textField.partialFormatter.formatPartial(textField.text ?? "")
        }
      }

      func phoneNumberFormattedForData() -> String {
        if let phoneNumber = textField.phoneNumber {
          return utility.format(phoneNumber, toType: .e164)
        } else if let text = textField.text, !text.isEmpty {
          return text.filter(\.isWholeNumber)
        } else {
          return ""
        }
      }
    }
  }

  struct ClerkPhoneNumberField: View {
    @Environment(\.clerkTheme) private var theme
    @State private var phoneNumberModel = PhoneNumberModel()
    @State private var reservedHeight: CGFloat?
    @State var displayText = ""
    @FocusState private var isFocused: Bool

    let titleKey: LocalizedStringKey
    @Binding var text: String

    init(
      _ titleKey: LocalizedStringKey,
      text: Binding<String>
    ) {
      self.titleKey = titleKey
      self._text = text
    }

    var isFocusedOrFilled: Bool {
      isFocused || !text.isEmpty
    }

    var offsetAmount: CGFloat {
      guard let reservedHeight else { return 0 }
      return reservedHeight * 0.333
    }

    private func textDidUpdate(text: String) {
      phoneNumberModel.textField.text = text
      self.displayText = phoneNumberModel.phoneNumberFormattedForDisplay()
      self.text = phoneNumberModel.phoneNumberFormattedForData()
    }

    @ViewBuilder
    var countrySelector: some View {
      Menu {
        Section("Default") {
          if let defaultCountry = phoneNumberModel.defaultCountry {
            Button {
              phoneNumberModel.setCountry(defaultCountry)
              textDidUpdate(text: text)
            } label: {
              Text(phoneNumberModel.stringForCountry(defaultCountry))
                .lineLimit(1)
            }
          }
        }

        Section("International") {
          ForEach(phoneNumberModel.allCountriesExceptDefault, id: \.code) { country in
            Button {
              phoneNumberModel.setCountry(country)
              textDidUpdate(text: text)
            } label: {
              Text(phoneNumberModel.stringForCountry(country))
                .lineLimit(1)
            }
          }
        }
      } label: {
        HStack(spacing: 4) {
          if let currentCountry = phoneNumberModel.currentCountry {
            Text(verbatim: "\(currentCountry.flag) \(currentCountry.code)")
              .font(theme.fonts.footnote)
              .foregroundStyle(theme.colors.text)
              .monospaced()
          }

          Image("icon-up-down", bundle: .module)
            .foregroundStyle(theme.colors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 13)
        .background(theme.colors.backgroundSecondary)
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
              .frame(maxWidth: .infinity, alignment: .leading)
              .opacity(0)

            HStack(spacing: 4) {
              if let prefix = phoneNumberModel.currentCountry?.prefix, isFocusedOrFilled {
                Text(prefix)
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
                .keyboardType(.numberPad)
                .tint(theme.colors.primary)
                .onChange(of: displayText) { oldValue, newValue in
                  textDidUpdate(text: newValue)
                }
            }
            .lineLimit(1)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.inputText)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(theme.colors.textSecondary)
            .allowsHitTesting(false)
            .offset(y: isFocusedOrFilled ? -offsetAmount : 0)
            .scaleEffect(isFocusedOrFilled ? (12 / 17) : 1, anchor: .topLeading)
            .animation(.default, value: isFocusedOrFilled)
        }
      }
      .padding(.horizontal, 6)
      .padding(.vertical, 6)
      .frame(minHeight: 56)
      .contentShape(.rect)
      .onTapGesture {
        isFocused = true
      }
      .background(
        theme.colors.inputBackground,
        in: .rect(cornerRadius: theme.design.borderRadius)
      )
      .clerkFocusedBorder(isFocused: isFocused)
      .onAppear {
        textDidUpdate(text: text)
      }
    }
  }

  #Preview {
    @Previewable @State var emptyEmail: String = ""
    @Previewable @State var filledEmail: String = "5555550100"

    VStack(spacing: 20) {
      ClerkPhoneNumberField("Enter your phone number", text: $emptyEmail)
      ClerkPhoneNumberField("Enter your phone number", text: $filledEmail)
    }
    .padding()
  }

#endif
