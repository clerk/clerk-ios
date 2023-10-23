//
//  PhoneNumberField.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

import SwiftUI
import PhoneNumberKit

extension PhoneNumberField {
    struct Model {
        
        private let phoneNumberKit = PhoneNumberKit()
        private let partialFormatter = PartialFormatter()
        
        func phoneNumberFormattedForDisplay(_ text: String) -> String {
            if let parsedText = try? phoneNumberKit.parse(text) {
                return phoneNumberKit.format(parsedText, toType: .national)
            } else {
                return partialFormatter.formatPartial(text)
            }
        }
        
        func phoneNumberFormattedForE164(_ text: String) -> String {
            do {
                let phoneNumber = try phoneNumberKit.parse(text)
                return phoneNumberKit.format(phoneNumber, toType: .e164)
            } catch {
                return partialFormatter.formatPartial(text)
            }
        }
    }
}

struct PhoneNumberField: View {
    @Binding var text: String
    @State private var displayNumber = ""
    
    private let model = Model()
    @FocusState private var isFocused: Bool
    @Environment(\.clerkTheme) private var clerkTheme
    
    var body: some View {
        HStack(spacing: 0) {
            Button {
                // show country picker
            } label: {
                HStack {
                    Text("🇺🇸")
                    Text("+1")
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.medium))
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
            .buttonStyle(.plain)
            
            TextField("", text: $displayNumber)
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
                    displayNumber = model.phoneNumberFormattedForDisplay(newValue)
                    text = model.phoneNumberFormattedForE164(newValue)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(.systemFill), lineWidth: 1)
        }
    }
}

#Preview {
    PhoneNumberField(text: .constant(""))
        .frame(height: 44)
        .padding()
}
