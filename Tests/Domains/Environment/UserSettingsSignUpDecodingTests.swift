@testable import ClerkKit
import Foundation
import Testing

struct UserSettingsSignUpDecodingTests {
  @Test(arguments: [true, false])
  func decodesWhetherMfaIsRequired(required: Bool) throws {
    let json = """
    {"custom_action_required":false,"progressive":true,"mode":"public","legal_consent_enabled":false,"mfa":{"required":\(required)}}
    """

    let signUp = try JSONDecoder.clerkDecoder.decode(Clerk.Environment.UserSettings.SignUp.self, from: Data(json.utf8))

    #expect(signUp.mfa?.required == required)
  }

  @Test
  func decodesWithoutTheMfaSetting() throws {
    let json = #"{"custom_action_required":false,"progressive":true,"mode":"public","legal_consent_enabled":false}"#

    let signUp = try JSONDecoder.clerkDecoder.decode(Clerk.Environment.UserSettings.SignUp.self, from: Data(json.utf8))

    #expect(signUp.mfa == nil)
  }
}
