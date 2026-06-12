#if os(iOS)

@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
struct UserProfileDeleteAccountConfirmationViewTests {
  @Test
  func deleteConfirmationUsesEnvironmentLocale() {
    #expect(
      UserProfileDeleteAccountConfirmationView.isValidDeleteConfirmation(
        "ELIMINAR",
        locale: Locale(identifier: "es")
      )
    )
    #expect(
      UserProfileDeleteAccountConfirmationView.isValidDeleteConfirmation(
        "SUPPRIMER",
        locale: Locale(identifier: "fr")
      )
    )
    #expect(
      !UserProfileDeleteAccountConfirmationView.isValidDeleteConfirmation(
        "DELETE",
        locale: Locale(identifier: "es")
      )
    )
  }
}

#endif
