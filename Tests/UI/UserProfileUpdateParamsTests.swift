#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct UserProfileUpdateParamsTests {
  private func user(username: String?, firstName: String?, lastName: String?) -> User {
    var user = User.mock
    user.username = username
    user.firstName = firstName
    user.lastName = lastName
    return user
  }

  @Test
  func editingOnlyTheFirstNameLeavesTheOtherFieldsOut() throws {
    let user = user(username: "jdoe", firstName: "John", lastName: "Doe")

    let params = try #require(UserProfileUpdateProfileView.updateParams(
      for: user,
      username: "jdoe",
      firstName: "Jane",
      lastName: "Doe"
    ))

    #expect(params.username == nil)
    #expect(params.firstName == "Jane")
    #expect(params.lastName == nil)
  }

  @Test
  func anUntouchedMissingUsernameIsNotSentAsBlank() throws {
    let user = user(username: nil, firstName: "John", lastName: nil)

    let params = try #require(UserProfileUpdateProfileView.updateParams(
      for: user,
      username: "",
      firstName: "Jane",
      lastName: ""
    ))

    #expect(params.username == nil)
    #expect(params.firstName == "Jane")
    #expect(params.lastName == nil)
  }

  @Test
  func clearingAnExistingValueSendsItAsBlank() throws {
    let user = user(username: "jdoe", firstName: "John", lastName: "Doe")

    let params = try #require(UserProfileUpdateProfileView.updateParams(
      for: user,
      username: "jdoe",
      firstName: "John",
      lastName: ""
    ))

    #expect(params.lastName == "")
    #expect(params.username == nil)
    #expect(params.firstName == nil)
  }

  @Test
  func fieldsTheFormDoesNotShowAreNeverSent() throws {
    let user = user(username: "jdoe", firstName: "John", lastName: "Doe")

    let params = try #require(UserProfileUpdateProfileView.updateParams(
      for: user,
      username: nil,
      firstName: "Jane",
      lastName: nil
    ))

    #expect(params.username == nil)
    #expect(params.lastName == nil)
  }

  @Test
  func nothingIsSentWhenNoFieldChanged() {
    let user = user(username: "jdoe", firstName: "John", lastName: nil)

    #expect(UserProfileUpdateProfileView.updateParams(
      for: user,
      username: "jdoe",
      firstName: "John",
      lastName: ""
    ) == nil)
  }
}

#endif
