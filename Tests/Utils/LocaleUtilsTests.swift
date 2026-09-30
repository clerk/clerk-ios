//
//  LocaleUtilsTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct LocaleUtilsTests {
  @Test
  func testUserLocale() throws {
    let preferredLanguage = try #require(Locale.preferredLanguages.first)

    #expect(LocaleUtils.userLocale() == preferredLanguage)
  }

  @Test
  func userLocaleFormat() {
    let locale = LocaleUtils.userLocale()

    #expect(locale.wholeMatch(of: /[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*/) != nil)
  }
}
