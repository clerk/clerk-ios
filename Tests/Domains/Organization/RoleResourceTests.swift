@testable import ClerkKit
import Foundation
import Testing

struct RoleResourceTests {
  @Test
  func decodesRolesPageWithNullDescriptions() throws {
    let data = Data(
      """
      {
        "data": [
          {
            "object": "role",
            "id": "role_1",
            "key": "org:member",
            "name": "Member",
            "description": "Default member role",
            "permissions": [],
            "is_creator_eligible": false,
            "created_at": 1700000000000,
            "updated_at": 1700000000000
          },
          {
            "object": "role",
            "id": "role_2",
            "key": "org:billing",
            "name": "Billing",
            "description": null,
            "permissions": [
              {
                "object": "permission",
                "id": "perm_1",
                "key": "org:invoices:read",
                "name": "Read invoices",
                "description": null,
                "type": "user",
                "created_at": 1700000000000,
                "updated_at": 1700000000000
              }
            ],
            "is_creator_eligible": false,
            "created_at": 1700000000000,
            "updated_at": 1700000000000
          }
        ],
        "total_count": 2
      }
      """.utf8
    )

    let page = try JSONDecoder.clerkDecoder.decode(ClerkPaginatedResponse<RoleResource>.self, from: data)

    #expect(page.data.map(\.key) == ["org:member", "org:billing"])
    #expect(page.data[0].description == "Default member role")
    #expect(page.data[1].description == nil)
    #expect(page.data[1].permissions.first?.description == nil)
  }
}
