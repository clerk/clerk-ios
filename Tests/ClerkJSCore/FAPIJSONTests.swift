import ClerkJSCore
import Foundation
import Testing

struct FAPIJSONTests {
  @Test
  func normalizeReplacesNullSignInUserData() throws {
    let url = try #require(Bundle.module.url(forResource: "null-user-data-client", withExtension: "json"))
    let data = try Data(contentsOf: url)

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(Client.self, from: data)
    }

    let client = try FAPIJSON.decodeClient(data)
    #expect(client.id == "client_fixture")
    let signIn = try #require(client.signIn)
    #expect(signIn.id == "sia_fixture")
    #expect(signIn.userData.imageUrl == "")
    #expect(signIn.userData.hasImage == false)
  }

  @Test
  func normalizeLeavesPresentUserData() throws {
    let url = try #require(Bundle.module.url(forResource: "null-user-data-client", withExtension: "json"))
    var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    var signIn = try #require(object["sign_in"] as? [String: Any])
    signIn["user_data"] = [
      "image_url": "https://img.clerk.test/a.png",
      "has_image": true,
      "first_name": "Ada",
    ]
    object["sign_in"] = signIn
    let data = try JSONSerialization.data(withJSONObject: object)

    let client = try FAPIJSON.decodeClient(data)
    let decodedSignIn = try #require(client.signIn)
    #expect(decodedSignIn.userData.imageUrl == "https://img.clerk.test/a.png")
    #expect(decodedSignIn.userData.hasImage)
    #expect(decodedSignIn.userData.firstName == "Ada")
  }

  @Test
  func normalizeReplacesNestedNullUserData() throws {
    let payload: [String: Any] = [
      "user_data": NSNull(),
      "nested": [
        "user_data": NSNull(),
      ],
      "items": [
        ["user_data": NSNull()],
      ],
    ]
    let normalized = try FAPIJSON.normalizeClientJSON(JSONSerialization.data(withJSONObject: payload))
    let object = try #require(JSONSerialization.jsonObject(with: normalized) as? [String: Any])
    let root = try #require(object["user_data"] as? [String: Any])
    #expect(root["image_url"] as? String == "")
    #expect(root["has_image"] as? Bool == false)
    let nested = try #require((object["nested"] as? [String: Any])?["user_data"] as? [String: Any])
    #expect(nested["image_url"] as? String == "")
    let item = try #require((object["items"] as? [[String: Any]])?.first?["user_data"] as? [String: Any])
    #expect(item["has_image"] as? Bool == false)
  }

  @Test
  func normalizePassesUnsignedClientThrough() throws {
    let url = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let client = try FAPIJSON.decodeClient(Data(contentsOf: url))
    #expect(client.id == "client_fixture")
    #expect(client.signIn == nil)
    #expect(client.sessions.isEmpty)
  }
}
