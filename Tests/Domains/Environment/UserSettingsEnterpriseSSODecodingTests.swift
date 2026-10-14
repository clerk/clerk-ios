@testable import ClerkKit
import Foundation
import Testing

struct UserSettingsEnterpriseSSODecodingTests {
  private func json(enterpriseSSO: String?) -> Data {
    let enterpriseSSOField = enterpriseSSO.map { #","enterprise_sso":\#($0)"# } ?? ""
    return Data("""
    {"attributes":{},"sign_up":{"custom_action_required":false,"progressive":true,"mode":"public","legal_consent_enabled":false},\
    "social":{},"actions":{"delete_self":false,"create_organization":false}\(enterpriseSSOField)}
    """.utf8)
  }

  @Test(arguments: [true, false])
  func decodesWhetherEnterpriseSSOIsEnabled(enabled: Bool) throws {
    let userSettings = try JSONDecoder.clerkDecoder.decode(
      Clerk.Environment.UserSettings.self,
      from: json(enterpriseSSO: #"{"enabled":\#(enabled),"self_serve_sso":false}"#)
    )

    #expect(userSettings.enterpriseSSO?.enabled == enabled)
  }

  @Test
  func decodesWithoutTheEnterpriseSSOSetting() throws {
    let userSettings = try JSONDecoder.clerkDecoder.decode(Clerk.Environment.UserSettings.self, from: json(enterpriseSSO: nil))

    #expect(userSettings.enterpriseSSO == nil)
  }
}
