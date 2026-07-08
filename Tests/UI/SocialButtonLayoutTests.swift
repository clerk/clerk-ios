@testable import ClerkKitUI
import Testing

@MainActor
struct SocialButtonLayoutTests {
  @Test
  func rowRangesBalanceFourItemsAcrossTwoRowsWhenThreeFit() {
    #expect(SocialButtonRowsLayout.rowRanges(itemCount: 4, maxItemsPerRow: 3) == [
      0 ..< 2,
      2 ..< 4,
    ])
  }

  @Test
  func rowRangesLeaveItemsInOneRowWhenTheyFit() {
    #expect(SocialButtonRowsLayout.rowRanges(itemCount: 4, maxItemsPerRow: 5) == [
      0 ..< 4,
    ])
  }

  @Test
  func rowRangesCanForceSingleColumnForTwoItems() {
    #expect(SocialButtonRowsLayout.rowRanges(itemCount: 2, maxItemsPerRow: 2, forceSingleColumn: true) == [
      0 ..< 1,
      1 ..< 2,
    ])
  }

  @Test
  func rowRangesPreservePartialFinalRowsForUnevenCounts() {
    #expect(SocialButtonRowsLayout.rowRanges(itemCount: 5, maxItemsPerRow: 3) == [
      0 ..< 3,
      3 ..< 5,
    ])
  }
}
