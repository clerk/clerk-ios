@testable import ClerkKit
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
  func maxRowItemCountCapsRowsAtFiveWhenContainerIsWide() {
    let layout = SocialButtonRowsLayout()

    #expect(layout.maxRowItemCount(containerWidth: 10000, subviewCount: 6) == 5)
  }

  @Test
  func rowRangesPreservePartialFinalRowsForUnevenCounts() {
    #expect(SocialButtonRowsLayout.rowRanges(itemCount: 5, maxItemsPerRow: 3) == [
      0 ..< 3,
      3 ..< 5,
    ])
  }

  @Test
  func rowRangesBalanceSixItemsAcrossTwoRowsWhenFiveFit() {
    #expect(SocialButtonRowsLayout.rowRanges(itemCount: 6, maxItemsPerRow: 5) == [
      0 ..< 3,
      3 ..< 6,
    ])
  }

  @Test
  func rowRangesMatchWebChunkingForSevenItemsAcrossThreeRows() {
    #expect(SocialButtonRowsLayout.rowRanges(itemCount: 7, maxItemsPerRow: 3) == [
      0 ..< 3,
      3 ..< 6,
      6 ..< 7,
    ])
  }

  @Test
  func socialButtonGroupShowsTitlesForCompactTwoProviderGroups() {
    #expect(SocialButtonGroup<Never>.showsTitle(
      isLastUsed: false,
      hasLastUsedProvider: false,
      remainingProviderCount: 2,
      stacksTwoItemsInSingleColumn: true
    ))
  }

  @Test
  func socialButtonGroupKeepsTwoProviderWideRowsShort() {
    #expect(SocialButtonGroup<Never>.showsTitle(
      isLastUsed: false,
      hasLastUsedProvider: false,
      remainingProviderCount: 2,
      stacksTwoItemsInSingleColumn: false
    ) == false)
  }

  @Test
  func socialButtonGroupKeepsCompactRemainingPairShortWhenLastUsedExists() {
    #expect(SocialButtonGroup<Never>.showsTitle(
      isLastUsed: false,
      hasLastUsedProvider: true,
      remainingProviderCount: 2,
      stacksTwoItemsInSingleColumn: true
    ) == false)
  }

  @Test
  func socialButtonGroupKeepsWideRemainingPairShortWhenLastUsedExists() {
    #expect(SocialButtonGroup<Never>.showsTitle(
      isLastUsed: false,
      hasLastUsedProvider: true,
      remainingProviderCount: 2,
      stacksTwoItemsInSingleColumn: false
    ) == false)
  }

  @Test
  func socialButtonGroupShowsTitleForLastUsedProvider() {
    #expect(SocialButtonGroup<Never>.showsTitle(
      isLastUsed: true,
      hasLastUsedProvider: true,
      remainingProviderCount: 2,
      stacksTwoItemsInSingleColumn: false
    ))
  }

  @Test
  func socialButtonGroupShowsTitleForSingleRemainingProvider() {
    #expect(SocialButtonGroup<Never>.showsTitle(
      isLastUsed: false,
      hasLastUsedProvider: true,
      remainingProviderCount: 1,
      stacksTwoItemsInSingleColumn: false
    ))
  }

  @Test
  func socialButtonGroupArrangesLastUsedProviderFirstWhenPresent() {
    #expect(SocialButtonGroup<Never>.arrangedProviders(
      providers: [.google, .apple],
      lastUsedProvider: .apple
    ) == [.apple, .google])
  }

  @Test
  func socialButtonGroupIgnoresLastUsedProviderWhenItIsUnavailable() {
    #expect(SocialButtonGroup<Never>.arrangedProviders(
      providers: [.google, .apple],
      lastUsedProvider: .github
    ) == [.google, .apple])
  }
}
