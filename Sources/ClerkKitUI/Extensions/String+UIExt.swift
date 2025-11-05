//
//  String+UIExt.swift
//  Clerk
//
//  Created by Mike Pitre on 4/29/25.
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
