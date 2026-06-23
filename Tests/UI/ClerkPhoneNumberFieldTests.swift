#if os(iOS)

@testable import ClerkKitUI
import Testing

@MainActor
struct ClerkPhoneNumberFieldTests {
  @Test
  func e164InputPreservesDataValueAndUpdatesCountry() {
    let model = ClerkPhoneNumberField.PhoneNumberModel()

    let formattedText = model.formattedText(for: "+447911123456")

    #expect(formattedText.dataText == "+447911123456")
    #expect(model.currentCountry.prefix == "+44")
  }
}

#endif
