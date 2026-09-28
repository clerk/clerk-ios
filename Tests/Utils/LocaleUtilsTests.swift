//
//  LocaleUtilsTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct LocaleUtilsTests {
  @Test
  func testUserLocale() {
    let locale = LocaleUtils.userLocale()

    #expect(!locale.isEmpty)

    let parts = locale.split(separator: "-")
    #expect(parts.count >= 1)
    #expect(parts[0].count >= 2)

    #expect(!locale.contains(" "))
  }

  @Test
  func userLocaleFormat() {
    let locale = LocaleUtils.userLocale()

    #expect(locale.count >= 2)

    let firstPart = locale.split(separator: "-").first ?? ""
    #expect(firstPart.allSatisfy { $0.isLetter })
  }
}
