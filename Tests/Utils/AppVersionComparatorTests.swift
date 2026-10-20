@testable import ClerkKit
import Testing

struct AppVersionComparatorTests {
  @Test(arguments: [
    ("1", "1.0.0", 0),
    ("1.2.3", "1.2.2", 1),
    ("2.0", "2.0.1", -1),
  ])
  func comparesNumericVersions(lhs: String, rhs: String, expected: Int) {
    #expect(AppVersionComparator.compare(lhs, rhs) == expected)
  }

  @Test(arguments: ["", "1.2.3.4", "1.0-beta", "v2"])
  func rejectsInvalidVersions(version: String) {
    #expect(!AppVersionComparator.isValid(version))
  }
}
