//
//  String+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 7/30/25.
//

import Foundation

public extension String {
  var isEmptyTrimmed: Bool {
    trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var nonBreaking: String {
    replacingOccurrences(of: " ", with: "\u{00A0}")
      .replacingOccurrences(of: "-", with: "\u{2011}")
  }

  var capitalizedSentence: String {
    let firstLetter = prefix(1).capitalized
    let remainingLetters = dropFirst().lowercased()
    return firstLetter + remainingLetters
  }

  var isEmailAddress: Bool {
    let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return emailPredicate.evaluate(with: self)
  }
}
