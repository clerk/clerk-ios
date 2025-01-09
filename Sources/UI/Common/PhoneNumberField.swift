//
//  PhoneNumberField.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

#if os(iOS)

import SwiftUI
import Factory
import PhoneNumberKit

extension PhoneNumberField {
    @Observable
    @MainActor
    final class Model {
        private let phoneNumberKit = Container.shared.phoneNumberKit()
        let textField: PhoneNumberTextField
        
        init() {
            self.textField = .init(withPhoneNumberKit: phoneNumberKit)
        }
        
        var allCountries: [CountryCodePickerViewController.Country] {
            phoneNumberKit
                .allCountries()
                .compactMap({ CountryCodePickerViewController.Country(for: $0, with: self.phoneNumberKit) })
                .sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        }
        
        var allCountriesExceptDefault: [CountryCodePickerViewController.Country] {
            allCountries.filter({ $0.code != defaultCountry?.code })
        }
        
        var exampleNumber: String {
            phoneNumberKit.getFormattedExampleNumber(
                forCountry: textField.currentRegion,
                withFormat: .national,
                withPrefix: false
            ) ?? ""
        }
        
        func phoneNumberFormattedForDisplay() -> String {
            if let phoneNumber = textField.phoneNumber {
                return phoneNumberKit.format(phoneNumber, toType: .national, withPrefix: false)
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
    
    @State var model = Model()
    @FocusState private var isFocused: Bool
    @Environment(\.clerkTheme) private var clerkTheme
    
    var body: some View {
        HStack(spacing: 0) {
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
                        Text(currentCountry.code)
                            .font(.footnote)
                            .foregroundStyle(clerkTheme.colors.textPrimary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.textSecondary)
                    }
                    .padding(.horizontal)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            Text(model.currentCountry?.prefix ?? "")
                .font(.footnote)
                .foregroundStyle(clerkTheme.colors.textPrimary)
            
            TextField(model.exampleNumber, text: $displayNumber)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .focused($isFocused)
                .font(.footnote)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                .padding(.horizontal)
                .tint(clerkTheme.colors.textPrimary)
                .onChange(of: displayNumber) { newValue in
                    textDidUpdate(text: newValue)
                }

        }
        .background()
        .clipShape(.rect(cornerRadius: 6, style: .continuous))
        .shadow(color: Color(red: 0.1, green: 0.11, blue: 0.13).opacity(0.06), radius: 0.5, x: 0, y: 1)
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(isFocused ? clerkTheme.colors.textPrimary : Color(.systemFill), lineWidth: 1)
        }
        .onAppear {
            textDidUpdate(text: text)
        }
    }
    
    private func textDidUpdate(text: String) {
        model.textField.text = text
        self.displayNumber = model.phoneNumberFormattedForDisplay()
        self.text = model.phoneNumberFormattedForData()
    }
}

#Preview {
    PhoneNumberField(text: .constant(""))
        .padding()
}

#endif
