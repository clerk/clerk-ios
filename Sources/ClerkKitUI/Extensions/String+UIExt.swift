//
//  String+UIExt.swift.swift
//  Clerk
//
//  Created by Mike Pitre on 4/29/25.
//

#if os(iOS)

import FactoryKit
import Foundation
import PhoneNumberKit

extension String {
    var formattedAsPhoneNumberIfPossible: String {
        let utility = Container.shared.phoneNumberUtility()
        let partialFormatter = PartialFormatter(utility: utility, withPrefix: true)
        return partialFormatter.formatPartial(self).nonBreaking
    }

    var isPhoneNumber: Bool {
        let utility = Container.shared.phoneNumberUtility()
        return utility.isValidPhoneNumber(self)
    }
}

#endif
