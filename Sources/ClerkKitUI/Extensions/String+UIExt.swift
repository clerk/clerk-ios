//
//  String+UIExt.swift.swift
//  Clerk
//
//  Created by Mike Pitre on 4/29/25.
//

#if os(iOS)

@_spi(Internal) import ClerkKit
import Foundation
import PhoneNumberKit

extension String {
    var formattedAsPhoneNumberIfPossible: String {
        let utility = PhoneNumberKitProvider.utility
        let partialFormatter = PartialFormatter(utility: utility, withPrefix: true)
        return partialFormatter.formatPartial(self).nonBreaking
    }

    var isPhoneNumber: Bool {
        let utility = PhoneNumberKitProvider.utility
        return utility.isValidPhoneNumber(self)
    }
}

#endif
