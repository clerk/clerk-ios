@testable import ClerkKit
import Testing

struct OIDCPromptTests {
  @Test
  func emptyArrayReturnsNil() {
    let prompts: [OIDCPrompt] = []
    #expect(prompts.serializedPrompt == nil)
  }

  @Test
  func singleNoneReturnsNone() {
    let prompts: [OIDCPrompt] = [.none]
    #expect(prompts.serializedPrompt == "none")
  }

  @Test
  func singlePromptReturnsValue() {
    #expect([OIDCPrompt.consent].serializedPrompt == "consent")
    #expect([OIDCPrompt.login].serializedPrompt == "login")
    #expect([OIDCPrompt.selectAccount].serializedPrompt == "select_account")
  }

  @Test
  func multiplePromptsJoinedWithSpace() throws {
    let prompts: [OIDCPrompt] = [.login, .consent]
    let values = try Set(#require(prompts.serializedPrompt?.split(separator: " ").map(String.init)))
    #expect(values == Set(["login", "consent"]))
  }

  @Test
  func duplicatePromptsAreDeduped() {
    let prompts: [OIDCPrompt] = [.login, .login]
    #expect(prompts.serializedPrompt == "login")
  }

  @Test
  func noneWithOtherPromptsPassesThrough() throws {
    let prompts: [OIDCPrompt] = [.none, .login]
    let values = try Set(#require(prompts.serializedPrompt?.split(separator: " ").map(String.init)))
    #expect(values == Set(["none", "login"]))
  }
}
