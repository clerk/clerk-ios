//
//  LocaleUtils.swift
//  Clerk
//
//  Created by Cursor Agent on 10/14/25.
//

import Foundation

enum LocaleUtils {
    /// Returns a BCP-47 language tag representing the user's preferred locale.
    /// Example: "en-US". Falls back to "en" if unavailable.
    static func userLocale() -> String {
        // Use Apple's recommended API for BCP-47 tags
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
            if let first = Locale.preferredLanguages.first {
                return first
            }
        } else {
            // Fallback: construct from current locale components
            let locale = Locale.current
            let language = locale.languageCode ?? "en"
            if let region = locale.regionCode, !region.isEmpty {
                return "\(language)-\(region)"
            }
            return language
        }
        return "en"
    }
}
