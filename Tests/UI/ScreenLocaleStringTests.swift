@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
struct ScreenLocaleStringTests {
  /// The languages in ClerkKitUI's string catalog.
  private nonisolated static let languages = [
    "ar", "de", "el", "en", "es", "fr", "hi", "it", "ja", "ko", "pl", "pt", "ro", "ru", "tr", "uk", "zh-Hans",
  ]

  @Test(arguments: languages)
  func deleteConfirmationExpectsTheWordItsInstructionShows(language: String) {
    let locale = Locale(identifier: language)

    let word = String(localizedInClerkUI: "DELETE", locale: locale)
    let instruction = String(localizedInClerkUI: "Type \"DELETE\" to continue", locale: locale)

    #expect(instruction.contains("\"\(word)\""))
    if language != "en" {
      #expect(word != "DELETE")
    }
  }

  @Test
  func removeConfirmationsUseTheScreenLocale() {
    let spanish = Locale(identifier: "es")
    let email = EmailAddress.mock

    #expect(RemoveResource.totp.title(locale: spanish) == "Eliminar verificación en dos pasos")
    #expect(
      RemoveResource.email(email).messageLine1(locale: spanish)
        == "\(email.emailAddress) será eliminado de esta cuenta. Ya no podrá iniciar sesión usando esta dirección de correo electrónico."
    )
  }
}
