@testable import ClerkKit
import Testing

struct AppVersionComparatorTests {
  @Test
  func equalWhenMissingTrailingSegments() {
    let result = AppVersionComparator.compare("1.2", "1.2.0")
    #expect(result == 0)
  }

  @Test
  func comparesNumericSegments() {
    let result = AppVersionComparator.compare("1.10", "1.2")
    #expect((result ?? 0) > 0)
  }

  @Test
  func rejectsInvalidFormat() {
    #expect(AppVersionComparator.compare("1.0-beta", "1.0") == nil)
    #expect(AppVersionComparator.compare("1..0", "1.0") == nil)
    #expect(AppVersionComparator.compare("1.0", "v1.0") == nil)
  }
}
