//
//  File.swift
//  Clerk
//
//  Created by Mike Pitre on 4/29/25.
//

#if os(iOS)

import Foundation
import PhoneNumberKit

enum PhoneNumberKitProvider {

    static let utility = PhoneNumberKit.PhoneNumberUtility()

    static var allCountries: [CountryCodePickerViewController.Country] {
        PhoneNumberKitProvider.utility
            .allCountries()
            .compactMap({
                CountryCodePickerViewController.Country(for: $0, with: PhoneNumberKitProvider.utility)
            })
            .sorted(by: {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            })
    }

    static func stringForCountry(_ country: CountryCodePickerViewController.Country) -> String {
        "\(country.flag) \(country.name) \(country.prefix)"
    }

}

#endif
