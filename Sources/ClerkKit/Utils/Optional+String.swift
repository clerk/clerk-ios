//
//  Optional+String.swift
//  Clerk
//

import Foundation

extension String? {
  /// Returns the wrapped string trimmed of whitespace and newlines, or `nil` when the result is empty.
  package var nilIfEmpty: String? {
    guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.isEmpty == false else {
      return nil
    }
    return trimmed
  }
}
