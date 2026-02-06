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

  var isPhoneNumber: Bool {
    let utility = PhoneNumberUtility()
    return utility.isValidPhoneNumber(self)
  }
}

#endif
