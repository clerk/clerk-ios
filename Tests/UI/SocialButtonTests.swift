@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct SocialButtonTests {
  @Test(arguments: [
    ("public", true),
    ("restricted", false),
    ("waitlist", false),
  ])
  func appleSignInTransferFollowsSignUpMode(
    signUpMode: String,
    expectedTransferable: Bool
  ) {
    var environment = Clerk.Environment.mock
    environment.userSettings.signUp.mode = signUpMode

    #expect(SocialButton.shouldTransferAppleSignIn(
      transferable: true,
      environment: environment
    ) == expectedTransferable)
  }

  @Test
  func appleSignInTransferRequiresLoadedEnvironment() {
    #expect(SocialButton.shouldTransferAppleSignIn(
      transferable: true,
      environment: nil
    ) == false)
  }

  @Test
  func appleSignInTransferPreservesIncomingFalseValue() {
    var environment = Clerk.Environment.mock
    environment.userSettings.signUp.mode = "public"

    #expect(SocialButton.shouldTransferAppleSignIn(
      transferable: false,
      environment: environment
    ) == false)
  }
}
