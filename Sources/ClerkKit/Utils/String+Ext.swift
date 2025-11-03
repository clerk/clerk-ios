//
//  String+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 7/30/25.
//

import Foundation

extension String {

  public var isEmptyTrimmed: Bool {
    trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  public var nonBreaking: String {
    self
      .replacingOccurrences(of: " ", with: "\u{00A0}")
      .replacingOccurrences(of: "-", with: "\u{2011}")
  }

  public var capitalizedSentence: String {
    let firstLetter = prefix(1).capitalized
    let remainingLetters = dropFirst().lowercased()
    return firstLetter + remainingLetters
  }

  public var isEmailAddress: Bool {
    let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return emailPredicate.evaluate(with: self)
  }
}
