//
//  PhoneNumberField.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

#if canImport(UIKit)

import SwiftUI
import PhoneNumberKit

extension PhoneNumberField {
    final class Model: ObservableObject {
        private let phoneNumberKit = PhoneNumberKit()
        let textField: PhoneNumberTextField
        
        init() {
            self.textField = .init(withPhoneNumberKit: phoneNumberKit)
        }
        
        lazy var allCountries: [CountryCodePickerViewController.Country] = phoneNumberKit
            .allCountries()
            .compactMap({ CountryCodePickerViewController.Country(for: $0, with: self.phoneNumberKit) })
            .sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        
        var allCountriesExceptDefault: [CountryCodePickerViewController.Country] {
            allCountries.filter({ $0.code != defaultCountry?.code })
        }
        
        var exampleNumber: String {
            phoneNumberKit.getFormattedExampleNumber(forCountry: textField.currentRegion, withPrefix: false) ?? ""
        }
        
        func phoneNumberFormattedForDisplay() -> String {
            if let phoneNumber = textField.phoneNumber {
                return phoneNumberKit.format(phoneNumber, toType: .national)
            } else {
                return textField.partialFormatter.formatPartial(textField.text ?? "")
            }
        }
        
        func phoneNumberFormattedForData() -> String {
            if let phoneNumber = textField.phoneNumber {
                return phoneNumberKit.format(phoneNumber, toType: .e164)
            } else {
                return textField.partialFormatter.formatPartial(textField.text ?? "")
            }
        }
        
        var defaultCountry: CountryCodePickerViewController.Country? {
            .init(for: textField.defaultRegion, with: phoneNumberKit)
        }
        
        var currentCountry: CountryCodePickerViewController.Country? {
            .init(for: textField.currentRegion, with: phoneNumberKit)
        }
        
        func setNewCountry(_ country: CountryCodePickerViewController.Country) {
            textField.partialFormatter.defaultRegion = country.code
        }
        
        func stringForCountry(_ country: CountryCodePickerViewController.Country) -> String {
            "\(country.flag) \(country.name) \(country.prefix)"
        }
    }
}

struct PhoneNumberField: View {
    @Binding var text: String
    @State private var displayNumber = ""
    
    @StateObject var model = Model()
    @FocusState private var isFocused: Bool
    @Environment(\.clerkTheme) private var clerkTheme
    
    var body: some View {
        HStack(spacing: 0) {
            Button {
                // show country picker
            } label: {
                HStack {
                    if let currentCountry = model.currentCountry {
                        Menu {
                            Section("Default") {
                                if let defaultCountry = model.defaultCountry {
                                    Button {
                                        model.setNewCountry(defaultCountry)
                                        textDidUpdate(text: displayNumber)
                                    } label: {
                                        Text(model.stringForCountry(defaultCountry))
                                            .lineLimit(1)
                                    }
                                }
                            }
                            
                            Section("International") {
                                ForEach(model.allCountriesExceptDefault, id: \.code) { country in
                                    Button {
                                        model.setNewCountry(country)
                                        textDidUpdate(text: displayNumber)
                                    } label: {
                                        Text(model.stringForCountry(country))
                                            .lineLimit(1)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(currentCountry.flag)
                                Text(currentCountry.prefix)
                                    .font(.subheadline.weight(.medium))
                                Image(systemName: "chevron.down")
                                    .font(.caption2.weight(.medium))
                            }
                            .padding(.horizontal)
                            .frame(maxHeight: .infinity)
                            .background {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 8,
                                    bottomLeadingRadius: 8
                                )
                                .foregroundStyle(Color(.quaternarySystemFill))
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            
            TextField(model.exampleNumber, text: $displayNumber)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .focused($isFocused)
                .font(.subheadline)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal)
                .tint(clerkTheme.colors.primary)
                .overlay {
                    UnevenRoundedRectangle(
                        bottomTrailingRadius: 8,
                        topTrailingRadius: 8
                    )
                    .strokeBorder(
                        isFocused ? clerkTheme.colors.primary : .clear,
                        lineWidth: 1
                    )
                }
                .onChange(of: displayNumber) { newValue in
                    textDidUpdate(text: newValue)
                }

        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(.systemFill), lineWidth: 1)
        }
    }
    
    private func textDidUpdate(text: String) {
        model.textField.text = text
        self.displayNumber = model.phoneNumberFormattedForDisplay()
        self.text = model.phoneNumberFormattedForData()
        model.objectWillChange.send()
    }
}

#Preview {
    PhoneNumberField(text: .constant(""))
        .frame(height: 44)
        .padding()
}

#endif
