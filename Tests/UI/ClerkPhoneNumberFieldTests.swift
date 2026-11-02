#if os(iOS)

@testable import ClerkKitUI
import Testing

@MainActor
struct ClerkPhoneNumberFieldTests {
  private func makeModel(selecting code: String) throws -> ClerkPhoneNumberField.PhoneNumberModel {
    let model = ClerkPhoneNumberField.PhoneNumberModel()
    model.currentCountry = try country(code, in: model)
    return model
  }

  private func country(
    _ code: String,
    in model: ClerkPhoneNumberField.PhoneNumberModel
  ) throws -> ClerkPhoneCountry {
    try #require(([model.defaultCountry] + model.allCountriesExceptDefault).first { $0.code == code })
  }

  @Test
  func e164InputPreservesDataValueAndUpdatesCountry() {
    let model = ClerkPhoneNumberField.PhoneNumberModel()

    let formattedText = model.formattedText(for: "+447911123456")

    #expect(formattedText.dataText == "+447911123456")
    #expect(model.currentCountry.prefix == "+44")
  }

  @Test
  func rejectedNumberKeepsSelectedCallingCode() throws {
    let model = try makeModel(selecting: "AU")

    let formattedText = model.formattedText(for: "4155552671")

    #expect(formattedText.dataText == "+614155552671")
    #expect(formattedText.displayText.filter(\.isWholeNumber) == "4155552671")
    #expect(model.currentCountry.code == "AU")
  }

  @Test(arguments: [
    (selected: "US", digits: "4362345678", expected: "+14362345678"),
    (selected: "AU", digits: "2015550142", expected: "+612015550142"),
    (selected: "US", digits: "447400123456", expected: "+1447400123456"),
  ])
  func rejectedNumberWithoutPlusIsNeverReadAsAnotherCountry(
    selected: String,
    digits: String,
    expected: String
  ) throws {
    let model = try makeModel(selecting: selected)

    let formattedText = model.formattedText(for: digits)

    #expect(formattedText.dataText == expected)
    #expect(model.currentCountry.code == selected)
  }

  @Test
  func emptyValueStaysEmpty() throws {
    let model = try makeModel(selecting: "AU")

    let formattedText = model.formattedText(for: "")

    #expect(formattedText.dataText.isEmpty)
    #expect(formattedText.displayText.isEmpty)
  }

  @Test
  func inputWithoutDigitsIsEmpty() throws {
    let model = try makeModel(selecting: "AU")

    #expect(model.formattedText(for: "+").dataText.isEmpty)
    #expect(model.formattedText(for: "+61").dataText.isEmpty)
    #expect(model.formattedText(for: "+61").displayText.isEmpty)
  }

  @Test
  func feedingRejectedNumberBackDoesNotDoubleCallingCode() throws {
    let model = try makeModel(selecting: "AU")
    let typed = model.formattedText(for: "4155552671")

    let reappeared = model.formattedText(for: typed.dataText)
    let redisplayed = model.formattedText(for: reappeared.displayText)

    #expect(reappeared.dataText == "+614155552671")
    #expect(reappeared.displayText == typed.displayText)
    #expect(redisplayed.dataText == "+614155552671")
    #expect(redisplayed.displayText == typed.displayText)
  }

  @Test
  func storedRejectedNumberRestoresItsCountryInANewField() throws {
    let typed = try makeModel(selecting: "AU").formattedText(for: "4155552671")
    let model = try makeModel(selecting: "US")

    let reappeared = model.formattedText(for: typed.dataText)
    let redisplayed = model.formattedText(for: reappeared.displayText)

    #expect(model.currentCountry.code == "AU")
    #expect(reappeared.dataText == "+614155552671")
    #expect(redisplayed.dataText == "+614155552671")
  }

  @Test
  func storedRejectedNumberKeepsSelectedCountryThatSharesItsCallingCode() throws {
    let model = try makeModel(selecting: "CA")

    let reappeared = model.formattedText(for: "+1415555267")

    #expect(model.currentCountry.code == "CA")
    #expect(reappeared.dataText == "+1415555267")
  }

  @Test
  func changingCountryMovesRejectedNumberToTheNewCallingCode() throws {
    let model = try makeModel(selecting: "AU")
    let typed = model.formattedText(for: "4155552671")

    model.currentCountry = try country("JP", in: model)
    let moved = model.formattedText(for: typed.displayText)

    #expect(moved.dataText == "+814155552671")
  }

  @Test
  func unknownCallingCodeFallsBackToSelectedCountry() throws {
    let model = try makeModel(selecting: "AU")

    let formattedText = model.formattedText(for: "+999123")

    #expect(model.currentCountry.code == "AU")
    #expect(formattedText.dataText == "+61999123")
  }

  @Test
  func fictionalUSNumberIsSentAsE164WhenUSIsSelected() throws {
    let model = try makeModel(selecting: "US")

    let formattedText = model.formattedText(for: "2015550142")

    #expect(formattedText.dataText == "+12015550142")
  }

  @Test
  func usTestNumberIsNotSentToTheUSWhileAnotherCountryIsSelected() throws {
    let model = try makeModel(selecting: "AU")

    let selectedAustralia = model.formattedText(for: "2015550142")
    model.currentCountry = try country("US", in: model)
    let selectedUS = model.formattedText(for: selectedAustralia.displayText)

    #expect(selectedAustralia.dataText == "+612015550142")
    #expect(selectedUS.dataText == "+12015550142")
  }
}

#endif
