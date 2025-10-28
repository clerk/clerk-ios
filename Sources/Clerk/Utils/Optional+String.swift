//
//  Optional+String.swift
//  Clerk
//
//  Created by OpenAI Assistant on 2024-05-17.
//

import Foundation

extension Optional where Wrapped == String {

  /// Returns the wrapped string trimmed of whitespace and newlines, or `nil` when the result is empty.
  var nilIfEmpty: String? {
    guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.isEmpty == false else {
      return nil
    }
    return trimmed
  }
}
