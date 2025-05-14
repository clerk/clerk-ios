//
//  String+PhoneNumber.swift.swift
//  Clerk
//
//  Created by Mike Pitre on 4/29/25.
//

#if os(iOS)

import Factory
import Foundation
import PhoneNumberKit

extension String {
  public var formattedAsPhoneNumberIfPossible: String {
    let utility = Container.shared.phoneNumberUtility()
    let partialFormatter = PartialFormatter(utility: utility, withPrefix: true)
    return partialFormatter.formatPartial(self)
  }
}

#endif
