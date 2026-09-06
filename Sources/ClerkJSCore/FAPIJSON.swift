import Foundation

public enum FAPIJSON {
  public static func normalizeClientJSON(_ data: Data) throws -> Data {
    let object = try JSONSerialization.jsonObject(with: data)
    return try JSONSerialization.data(withJSONObject: normalizeWireValue(object))
  }

  public static func decodeClient(_ data: Data) throws -> Client {
    try JSONDecoder().decode(Client.self, from: normalizeClientJSON(data))
  }

  private static let emptyArrayKeys: Set<String> = [
    "supported_first_factors",
    "supported_second_factors",
    "supported_identifiers",
  ]

  private static let verificationKeys: Set<String> = [
    "first_factor_verification",
    "second_factor_verification",
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
        } else {
          normalized[key] = normalizeWireValue(nested)
        }
      }
      return normalized
    case let array as [Any]:
      return array.map(normalizeWireValue)
    default:
      return value
    }
  }

  private static func defaultVerification(_ object: [String: Any]) -> [String: Any] {
    var verification = object
    if verification["verified_at_client"] == nil || verification["verified_at_client"] is NSNull {
      verification["verified_at_client"] = ""
    }
    if verification["error"] == nil || verification["error"] is NSNull {
      verification["error"] = ["code": "", "message": ""]
    }
    if verification["id"] == nil || verification["id"] is NSNull {
      verification["id"] = ""
    }
    if verification["object"] == nil || verification["object"] is NSNull {
      verification["object"] = "verification"
    }
    if verification["attempts"] == nil || verification["attempts"] is NSNull {
      verification["attempts"] = 0
    }
    if verification["expire_at"] == nil || verification["expire_at"] is NSNull {
      verification["expire_at"] = 0
    }
    if verification["strategy"] == nil || verification["strategy"] is NSNull {
      verification["strategy"] = ""
    }
    return verification
  }
}
