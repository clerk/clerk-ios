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
        
        private var partialFormatter: PartialFormatter {
            textField.partialFormatter
        }
        
        init() {
            self.textField = .init(withPhoneNumberKit: phoneNumberKit)
        }
        
        lazy var allCountries = phoneNumberKit
            .allCountries()
            .compactMap({ CountryCodePickerViewController.Country(for: $0, with: self.phoneNumberKit) })
            .sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        
        var exampleNumber: String {
            phoneNumberKit.getFormattedExampleNumber(forCountry: textField.currentRegion, withPrefix: false) ?? ""
        }
        
        func phoneNumberFormattedForDisplay() -> String {
            if let phoneNumber = textField.phoneNumber {
                return phoneNumberKit.format(phoneNumber, toType: .national)
            } else {
                return partialFormatter.formatPartial(textField.text ?? "")
            }
        }
        
        func phoneNumberFormattedForData() -> String {
            if let phoneNumber = textField.phoneNumber {
                return phoneNumberKit.format(phoneNumber, toType: .e164)
            } else {
                return partialFormatter.formatPartial(textField.text ?? "")
            }
        }
        
        var currentCountry: CountryCodePickerViewController.Country? {
            .init(for: textField.currentRegion, with: phoneNumberKit)
        }
        
        func setNewCountry(_ country: CountryCodePickerViewController.Country) {
            partialFormatter.defaultRegion = country.code
            objectWillChange.send()
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
                            ForEach(model.allCountries, id: \.name) { country in
                                Button {
                                    model.setNewCountry(country)
                                    textDidUpdate(text: displayNumber)
                                } label: {
                                    Text("\(country.flag) \(country.name) \(country.prefix)")
                                        .lineLimit(1)
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
