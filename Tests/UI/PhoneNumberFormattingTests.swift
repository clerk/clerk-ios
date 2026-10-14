#if os(iOS)

@testable import ClerkKitUI
import PhoneNumberKit
import Testing

@MainActor
struct PhoneNumberFormattingTests {
  @Test(arguments: ["+15555550100", "+447911123456", "5555550100", "user@example.com"])
  func sharedUtilityFormatsLikeFreshUtility(input: String) {
    let freshFormatter = PartialFormatter(utility: PhoneNumberUtility(), withPrefix: true)

    #expect(input.formattedAsPhoneNumberIfPossible == freshFormatter.formatPartial(input).nonBreaking)
  }
}

#endif
