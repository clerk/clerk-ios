//
//  String+UIExt.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation
import PhoneNumberKit

extension String {
  /// Looks `key` up in ClerkKitUI's strings in `locale`'s language, the way SwiftUI `Text` does.
  ///
  /// `String(localized:bundle:locale:)` uses `locale` only to format interpolated values, and picks the
  /// app's language. When an app overrides the environment locale, it disagrees with the text on screen.
  init(localizedInClerkUI key: String.LocalizationValue, locale: Locale) {
    var resource = LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    resource.locale = locale
    self.init(localized: resource)
  }

  @MainActor
  var formattedAsPhoneNumberIfPossible: String {
    let partialFormatter = PartialFormatter(utility: .shared, withPrefix: true)
    return partialFormatter.formatPartial(self).nonBreaking
  }

  /// Strict phone number validation using PhoneNumberKit.
  @MainActor
  var isPhoneNumber: Bool {
    PhoneNumberUtility.shared.isValidPhoneNumber(self)
  }

  /// Loose phone number detection using NSDataDetector.
  var looksLikePhoneNumber: Bool {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue) else {
      return false
    }
    let range = NSRange(startIndex..., in: self)
    let matches = detector.matches(in: self, options: [], range: range)
    return matches.count == 1 && matches.first?.range == range
  }
}

#endif
