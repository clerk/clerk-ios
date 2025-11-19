//
//  LocaleUtilsTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct LocaleUtilsTests {
  @Test
  func testUserLocale() {
    let locale = LocaleUtils.userLocale()

    // Should return a non-empty string
    #expect(!locale.isEmpty)

    // Should be a valid BCP-47 language tag format (contains at least a language code)
    let parts = locale.split(separator: "-")
    #expect(parts.count >= 1)
    #expect(parts[0].count >= 2) // Language code should be at least 2 characters

    // Should not contain spaces
    #expect(!locale.contains(" "))
  }

  @Test
  func userLocaleFormat() {
    let locale = LocaleUtils.userLocale()

    // Should be in format like "en" or "en-US" or "en_US" (though BCP-47 uses hyphens)
    // Typically BCP-47 uses hyphens, but we'll just verify it's not empty
    // and has a reasonable structure
    #expect(locale.count >= 2)

    // First part should be alphabetic (language code)
    let firstPart = locale.split(separator: "-").first ?? ""
    #expect(firstPart.allSatisfy { $0.isLetter })
  }
}
