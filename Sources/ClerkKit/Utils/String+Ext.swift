//
//  String+Ext.swift
//  Clerk
//

import Foundation

extension String {
  package var isEmptyTrimmed: Bool {
    trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  package var nonBreaking: String {
    replacingOccurrences(of: " ", with: "\u{00A0}")
      .replacingOccurrences(of: "-", with: "\u{2011}")
  }

  package var capitalizedSentence: String {
    let firstLetter = prefix(1).capitalized
    let remainingLetters = dropFirst().lowercased()
    return firstLetter + remainingLetters
  }

  package var looksLikeEmailAddress: Bool {
    contains("@")
  }
}
