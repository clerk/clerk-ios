//
//  String+UIExt.swift
//  Clerk
//

#if os(iOS)

import Foundation
import PhoneNumberKit

extension String {
  var formattedAsPhoneNumberIfPossible: String {
    let utility = PhoneNumberUtility()
    let partialFormatter = PartialFormatter(utility: utility, withPrefix: true)
    return partialFormatter.formatPartial(self).nonBreaking
  }

  /// Strict phone number validation using PhoneNumberKit.
  var isPhoneNumber: Bool {
    let utility = PhoneNumberUtility()
    return utility.isValidPhoneNumber(self)
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
