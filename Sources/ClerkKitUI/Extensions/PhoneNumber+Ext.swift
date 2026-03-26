//
//  PhoneNumber+Ext.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation
import PhoneNumberKit

struct ClerkPhoneCountry: Equatable, Hashable {
  let code: String
  let flag: String
  let name: String
  let prefix: String

  init?(for countryCode: String, with utility: PhoneNumberUtility) {
    let flagBase = UnicodeScalar("🇦").value - UnicodeScalar("A").value

    guard
      let name = (Locale.current as NSLocale).localizedString(forCountryCode: countryCode),
      let prefix = utility.countryCode(for: countryCode)?.description
    else {
      return nil
    }

    code = countryCode
    self.name = name
    self.prefix = "+" + prefix

    var flag = ""
    for unicodeScalar in countryCode.uppercased().unicodeScalars {
      if let scalar = UnicodeScalar(flagBase + unicodeScalar.value) {
        flag.append(String(describing: scalar))
      }
    }

    guard flag.count != 1 else {
      return nil
    }

    self.flag = flag
  }
}

extension PhoneNumberKit.PhoneNumberUtility {
  var allCountries: [ClerkPhoneCountry] {
    self
      .allCountries()
      .compactMap {
        ClerkPhoneCountry(for: $0, with: self)
      }
      .sorted(by: {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      })
  }
}

#endif
