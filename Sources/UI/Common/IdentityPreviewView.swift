//
//  IdentityPreviewView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if canImport(UIKit)

import SwiftUI
import NukeUI
import PhoneNumberKit

struct IdentityPreviewView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    var imageUrl: String?
    var label: String?
    var action: (() -> Void)?
    
    private let phoneNumberKit = PhoneNumberKit()
    
    var body: some View {
        HStack(alignment: .center) {
            if let imageUrl {
                LazyImage(
                    url: URL(string: imageUrl),
                    transaction: Transaction(animation: .default)
                ) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color(.secondarySystemBackground)
                    }
                }
                .frame(width: 20, height: 20)
                .clipShape(Circle())
            } else if 
                let label,
                let phoneNumber = try? phoneNumberKit.parse(label),
                let country = CountryCodePickerViewController.Country(for: phoneNumber.regionID ?? "", with: phoneNumberKit)
            {
                Text(country.flag)
            }
            
            if let label {
                Text(label)
                    .font(.footnote.weight(.light))
            }
            
            if let action {
                Button(action: {
                    action()
                }, label: {
                    Image(systemName: "square.and.pencil")
                        .bold()
                        .foregroundStyle(clerkTheme.colors.textPrimary)
                })
            }
        }
        .padding(10)
        .padding(.horizontal, 6)
        .overlay {
            Capsule()
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }
}

#Preview {
    IdentityPreviewView(
        imageUrl: "",
        label: "clerkuser@gmail.com",
        action: {}
    )
}

#endif
