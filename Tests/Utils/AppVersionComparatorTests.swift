@testable import ClerkKit
import Testing

struct AppVersionComparatorTests {
  @Test(arguments: [
    ("1", "1.0.0", true),
    ("1.2.3", "1.2.2", true),
    ("2.0", "2.0.1", false),
    ("10.0", "9.9", true),
  ])
  func comparesNumericVersions(current: String, minimum: String, expected: Bool) {
    #expect(AppVersionComparator.isSupported(current: current, minimum: minimum) == expected)
  }

  @Test(arguments: ["", "1.2.3.4", "1.0-beta", "v2", "99999999999999999999"])
  func rejectsInvalidVersions(version: String) {
    #expect(AppVersionComparator.isSupported(current: version, minimum: "1.0") == nil)
    #expect(AppVersionComparator.isSupported(current: "1.0", minimum: version) == nil)
  }
}
