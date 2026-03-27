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
    let normalizedCode = countryCode.uppercased()
    let flagBase = UnicodeScalar("🇦").value - UnicodeScalar("A").value
    let fallbackLocale = Locale(identifier: "en_US_POSIX")

    guard
      normalizedCode.count == 2,
      normalizedCode.unicodeScalars.allSatisfy(CharacterSet.letters.contains),
      let name = Locale.current.localizedString(forRegionCode: normalizedCode)
      ?? fallbackLocale.localizedString(forRegionCode: normalizedCode),
      let prefix = utility.countryCode(for: normalizedCode)?.description
    else {
      return nil
    }

    code = normalizedCode
    self.name = name
    self.prefix = "+" + prefix

    var flag = ""
    for unicodeScalar in normalizedCode.unicodeScalars {
      if let scalar = UnicodeScalar(flagBase + unicodeScalar.value) {
        flag.append(String(describing: scalar))
      }
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
