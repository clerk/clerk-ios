//
//  PhoneNumber+Ext.swift
//  Clerk
//

#if os(iOS)

import Foundation
import PhoneNumberKit

extension PhoneNumberKit.PhoneNumberUtility {
  var allCountries: [CountryCodePickerViewController.Country] {
    self
      .allCountries()
      .compactMap {
        CountryCodePickerViewController.Country(for: $0, with: self)
      }
      .sorted(by: {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      })
  }
}

#endif
