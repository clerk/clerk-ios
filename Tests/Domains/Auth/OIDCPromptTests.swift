@testable import ClerkKit
import Testing

struct OIDCPromptTests {
  @Test
  func emptyArrayReturnsNil() throws {
    let prompts: [OIDCPrompt] = []
    #expect(try prompts.validatedPrompt() == nil)
  }

  @Test
  func singleNoneReturnsNone() throws {
    let prompts: [OIDCPrompt] = [.none]
    #expect(try prompts.validatedPrompt() == "none")
  }

  @Test
  func singlePromptReturnsValue() throws {
    #expect(try [OIDCPrompt.consent].validatedPrompt() == "consent")
    #expect(try [OIDCPrompt.login].validatedPrompt() == "login")
    #expect(try [OIDCPrompt.selectAccount].validatedPrompt() == "select_account")
  }

  @Test
  func multiplePromptsJoinedWithSpace() throws {
    let prompts: [OIDCPrompt] = [.login, .consent]
    #expect(try prompts.validatedPrompt() == "login consent")
  }

  @Test
  func noneWithOtherPromptsThrows() throws {
    let prompts: [OIDCPrompt] = [.none, .login]
    #expect {
      try prompts.validatedPrompt()
    } throws: { error in
      let clientError = error as? ClerkClientError
      return clientError?.message?.contains("\"none\" cannot be combined") == true
    }
  }

  @Test
  func duplicatePromptsThrows() throws {
    let prompts: [OIDCPrompt] = [.login, .login]
    #expect {
      try prompts.validatedPrompt()
    } throws: { error in
      let clientError = error as? ClerkClientError
      return clientError?.message?.contains("Duplicate") == true
    }
  }
}
