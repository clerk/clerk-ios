@testable import ClerkKitUI
import Testing

@MainActor
struct SocialButtonLayoutTests {
  @Test
  func rowRangesBalanceFourItemsAcrossTwoRowsWhenThreeFit() {
    #expect(SocialButtonLayout.rowRanges(itemCount: 4, maxItemsPerRow: 3) == [
      0 ..< 2,
      2 ..< 4,
    ])
  }

  @Test
  func rowRangesLeaveItemsInOneRowWhenTheyFit() {
    #expect(SocialButtonLayout.rowRanges(itemCount: 4, maxItemsPerRow: 5) == [
      0 ..< 4,
    ])
  }

  @Test
  func rowRangesPreservePartialFinalRowsForUnevenCounts() {
    #expect(SocialButtonLayout.rowRanges(itemCount: 5, maxItemsPerRow: 3) == [
      0 ..< 3,
      3 ..< 5,
    ])
  }
}
