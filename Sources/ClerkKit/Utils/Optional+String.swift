//
//  Optional+String.swift
//  Clerk
//
//  Created by Mike Pitre on 5/17/24.
//

import Foundation

package extension String? {
  /// Returns the wrapped string trimmed of whitespace and newlines, or `nil` when the result is empty.
  var nilIfEmpty: String? {
    guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.isEmpty == false else {
      return nil
    }
    return trimmed
  }
}
