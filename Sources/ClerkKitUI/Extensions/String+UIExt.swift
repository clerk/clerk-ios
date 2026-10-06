//
//  String+UIExt.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation
import PhoneNumberKit

extension String {
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
