#if os(iOS)

@testable import ClerkKitUI
import Testing

@MainActor
struct OrganizationSlugTests {
  @Test(arguments: [
    ("Acme Inc.", "acme-inc"),
    ("(Acme)", "acme"),
    ("  Acme  ", "acme"),
    ("Acme & Co", "acme-co"),
    ("Éclair", "clair"),
    ("Acme 7c1e", "acme-7c1e"),
  ])
  func generatedSlugHasNoSurroundingHyphens(name: String, expected: String) {
    let slug = OrganizationProfileFormView.createSlug(from: name)

    #expect(slug == expected)
    #expect(OrganizationProfileFormView.isValidSlug(slug))
  }

  @Test(arguments: ["", "   ", "!!!", "---", "日本語"])
  func nameWithoutSlugCharactersGeneratesEmptySlugThatFailsValidation(name: String) {
    let slug = OrganizationProfileFormView.createSlug(from: name)

    #expect(slug.isEmpty)
    #expect(!OrganizationProfileFormView.isValidSlug(slug))
  }

  @Test
  func typingNameCharacterByCharacterReachesFinalSlug() {
    let name = "acme-inc"
    let slugs = name.indices.map { index in
      OrganizationProfileFormView.createSlug(from: String(name[...index]))
    }

    #expect(slugs == ["a", "ac", "acm", "acme", "acme", "acme-i", "acme-in", "acme-inc"])
    #expect(slugs.allSatisfy(OrganizationProfileFormView.isValidSlug))
  }

  @Test(arguments: ["a", "1", "acme", "acme-inc", "valid--slug", "validslug123"])
  func slugsTheBackendAcceptsAreValid(slug: String) {
    #expect(OrganizationProfileFormView.isValidSlug(slug))
  }

  @Test(arguments: ["", "-", "--", "-acme", "acme-", "-acme-", "Acme", "acme inc", "acme!"])
  func slugsTheBackendRejectsAreInvalid(slug: String) {
    #expect(!OrganizationProfileFormView.isValidSlug(slug))
  }
}

#endif
