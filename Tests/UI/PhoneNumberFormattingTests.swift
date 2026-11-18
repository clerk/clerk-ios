#if os(iOS)

@testable import ClerkKitUI
import PhoneNumberKit
import Testing

@MainActor
struct PhoneNumberFormattingTests {
  @Test(arguments: [
    (input: "+15555550100", expected: "+1\u{00A0}(555)\u{00A0}555\u{2011}0100"),
    (input: "+447911123456", expected: "+44\u{00A0}7911\u{00A0}123456"),
    (input: "user@example.com", expected: "user@example.com"),
  ])
  func phoneNumbersGetRegionGroupingWithNonBreakingSeparators(input: String, expected: String) {
    #expect(input.formattedAsPhoneNumberIfPossible == expected)
  }

  @Test
  func nationalNumberFormatsForTheDeviceRegion() {
    let freshFormatter = PartialFormatter(utility: PhoneNumberUtility(), withPrefix: true)

    #expect("5555550100".formattedAsPhoneNumberIfPossible == freshFormatter.formatPartial("5555550100").nonBreaking)
  }
}

#endif
