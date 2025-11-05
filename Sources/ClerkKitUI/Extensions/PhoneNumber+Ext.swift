//
//  File.swift
//  Clerk
//
//  Created by Mike Pitre on 4/29/25.
//

#if os(iOS)

import Foundation
import PhoneNumberKit

extension PhoneNumberKit.PhoneNumberUtility {

  var allCountries: [CountryCodePickerViewController.Country] {
    self
      .allCountries()
      .compactMap({
        CountryCodePickerViewController.Country(for: $0, with: self)
      })
      .sorted(by: {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      })
  }

}

#endif
