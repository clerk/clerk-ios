//
//  String+Ext.swift.swift
//  Clerk
//
//  Created by Mike Pitre on 4/29/25.
//

#if os(iOS)

  import Factory
  import Foundation
  import PhoneNumberKit

  extension String {
    var formattedAsPhoneNumberIfPossible: String {
      let utility = Container.shared.phoneNumberUtility()
      let partialFormatter = PartialFormatter(utility: utility, withPrefix: true)
      return partialFormatter.formatPartial(self).nonBreaking
    }

    var nonBreaking: String {
      self
        .replacingOccurrences(of: " ", with: "\u{00A0}")
        .replacingOccurrences(of: "-", with: "\u{2011}")
    }

    var capitalizedSentence: String {
      let firstLetter = self.prefix(1).capitalized
      let remainingLetters = self.dropFirst().lowercased()
      return firstLetter + remainingLetters
    }

    var isEmptyTrimmed: Bool {
      trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isEmailAddress: Bool {
      let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
      let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
      return emailPredicate.evaluate(with: self)
    }
    
    var isPhoneNumber: Bool {
      let utility = Container.shared.phoneNumberUtility()
      return utility.isValidPhoneNumber(self)
    }
  }

#endif
