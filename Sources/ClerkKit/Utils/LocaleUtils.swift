//
//  LocaleUtils.swift
//  Clerk
//
//  Created by Mike Pitre on 10/14/25.
//

import Foundation

enum LocaleUtils {
  /// Returns a BCP-47 language tag representing the user's preferred locale.
  /// Example: "en-US". Falls back to "en" if unavailable.
  static func userLocale() -> String {
    if let first = Locale.preferredLanguages.first, !first.isEmpty {
      return first
    }

    // Fallback: construct from current locale components
    let locale = Locale.current
    let languageCode = locale.language.languageCode ?? "en"
    if let region = locale.region?.identifier, !region.isEmpty {
      return "\(languageCode)-\(region)"
    }
    return "\(languageCode)"
  }
}
