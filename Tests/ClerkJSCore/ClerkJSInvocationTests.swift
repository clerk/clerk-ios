import ClerkJSCore
import Foundation
import Testing

struct ClerkJSInvocationTests {
  @Test
  func listedReceiverEncodesKindAndIdWithoutDuplicatedScope() throws {
    let receiver = ClerkJSReceiver.listed(.userOrganizationInvitation, id: ClerkJSResourceID("inv_1"))
    let data = try JSONEncoder().encode(receiver)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["kind"] as? String == "listed")
    #expect(object["listedKind"] as? String == "userOrganizationInvitation")
    #expect(object["id"] as? String == "inv_1")
    #expect(object["scope"] == nil)
  }

  @Test
  func userUpdateBindsParamsAndMethodName() throws {
    let call = UserJSCall.update(UpdateUserParams(firstName: "Ada"))
    #expect(call.jsMethod == "update")
    #expect(try call.jsArguments() == [.object(["firstName": .string("Ada")])])
  }

  @Test
  func optionalReloadOmitsNilArgument() throws {
    #expect(try UserJSCall.reload(nil).jsArguments().isEmpty)
  }

  @Test
  func invocationCarriesReceiverAndCall() throws {
    let invocation = try ClerkJSInvocation(.user(id: .init("user_1")), UserJSCall.createTOTP)
    #expect(invocation.receiver == .user(id: .init("user_1")))
    #expect(invocation.method == "createTOTP")
    #expect(invocation.arguments.isEmpty)
  }
}
