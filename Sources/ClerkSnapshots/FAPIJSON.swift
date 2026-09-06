import Foundation

public enum FAPIJSON {
  public static func normalizeClientJSON(_ data: Data) throws -> Data {
    let object = try JSONSerialization.jsonObject(with: data)
    return try JSONSerialization.data(withJSONObject: normalizeWireValue(object))
  }

  public static func decodeClient(_ data: Data) throws -> Client {
    try JSONDecoder().decode(Client.self, from: normalizeClientJSON(data))
  }

  public static func encodeClient(_ client: Client) throws -> Data {
    try JSONEncoder().encode(client)
  }

  private static let emptyArrayKeys: Set<String> = [
    "supported_first_factors",
    "supported_second_factors",
    "supported_identifiers",
  ]

  private static let verificationKeys: Set<String> = [
    "first_factor_verification",
    "second_factor_verification",
    "verification",
  ]

  private static let userArrayKeys: Set<String> = [
    "email_addresses",
    "phone_numbers",
    "web3_wallets",
    "external_accounts",
    "enterprise_accounts",
    "passkeys",
    "organization_memberships",
  ]

  private static let userBoolKeys: Set<String> = [
    "has_image",
    "password_enabled",
    "totp_enabled",
    "backup_code_enabled",
    "two_factor_enabled",
    "create_organization_enabled",
    "delete_self_enabled",
  ]

  private static func normalizeWireValue(_ value: Any) -> Any {
    switch value {
    case let object as [String: Any]:
      var normalized: [String: Any] = [:]
      normalized.reserveCapacity(object.count)
      for (key, nested) in object {
        if key == "user_data", nested is NSNull {
          normalized[key] = ["image_url": "", "has_image": false]
        } else if emptyArrayKeys.contains(key), nested is NSNull {
          normalized[key] = [Any]()
        } else if verificationKeys.contains(key), let verification = nested as? [String: Any] {
          normalized[key] = defaultVerification(normalizeWireValue(verification) as? [String: Any] ?? verification)
        } else if key == "last_active_token", nested is NSNull {
          normalized[key] = defaultToken([:])
        } else if key == "public_user_data", nested is NSNull {
          normalized[key] = defaultPublicUserData([:])
        } else if key == "public_user_data", let data = nested as? [String: Any] {
          normalized[key] = defaultPublicUserData(normalizeWireValue(data) as? [String: Any] ?? data)
        } else {
          normalized[key] = normalizeWireValue(nested)
        }
      }
      return applyTypedDefaults(normalized)
    case let array as [Any]:
      return array.map(normalizeWireValue)
    default:
      return value
    }
  }

  private static func applyTypedDefaults(_ object: [String: Any]) -> [String: Any] {
    switch object["object"] as? String {
    case "user":
      defaultUser(object)
    case "session":
      defaultSession(object)
    case "token":
      defaultToken(object)
    case "email_address":
      defaultEmailAddress(object)
    default:
      object
    }
  }

  private static func missing(_ object: [String: Any], _ key: String) -> Bool {
    object[key] == nil || object[key] is NSNull
  }

  private static func defaultSession(_ object: [String: Any]) -> [String: Any] {
    var session = object
    if missing(session, "last_active_token") {
      session["last_active_token"] = defaultToken([:])
    }
    if missing(session, "public_user_data") {
      session["public_user_data"] = defaultPublicUserData([:])
    }
    return session
  }

  private static func defaultUser(_ object: [String: Any]) -> [String: Any] {
    var user = object
    if missing(user, "object") {
      user["object"] = "user"
    }
    if missing(user, "image_url") {
      user["image_url"] = ""
    }
    if missing(user, "profile_image_id") {
      user["profile_image_id"] = ""
    }
    for key in userArrayKeys where missing(user, key) {
      user[key] = [Any]()
    }
    for key in userBoolKeys where missing(user, key) {
      user[key] = false
    }
    if missing(user, "public_metadata") {
      user["public_metadata"] = [String: Any]()
    }
    if missing(user, "unsafe_metadata") {
      user["unsafe_metadata"] = [String: Any]()
    }
    return user
  }

  private static func defaultToken(_ object: [String: Any]) -> [String: Any] {
    var token = object
    if missing(token, "object") {
      token["object"] = "token"
    }
    if missing(token, "jwt") {
      token["jwt"] = ""
    }
    if missing(token, "id") {
      token["id"] = ""
    }
    return token
  }

  private static func defaultPublicUserData(_ object: [String: Any]) -> [String: Any] {
    var data = object
    if missing(data, "image_url") {
      data["image_url"] = ""
    }
    if missing(data, "has_image") {
      data["has_image"] = false
    }
    if missing(data, "identifier") {
      data["identifier"] = ""
    }
    return data
  }

  private static func defaultEmailAddress(_ object: [String: Any]) -> [String: Any] {
    var email = object
    if missing(email, "linked_to") {
      email["linked_to"] = [Any]()
    }
    if missing(email, "matches_sso_connection") {
      email["matches_sso_connection"] = false
    }
    return email
  }

  private static func defaultVerification(_ object: [String: Any]) -> [String: Any] {
    var verification = object
    if missing(verification, "verified_at_client") {
      verification["verified_at_client"] = ""
    }
    if missing(verification, "error") {
      verification["error"] = ["code": "", "message": ""]
    }
    if missing(verification, "id") {
      verification["id"] = ""
    }
    if missing(verification, "object") {
      verification["object"] = "verification"
    }
    if missing(verification, "attempts") {
      verification["attempts"] = 0
    }
    if missing(verification, "expire_at") {
      verification["expire_at"] = 0
    }
    if missing(verification, "strategy") {
      verification["strategy"] = ""
    }
    return verification
  }
}
