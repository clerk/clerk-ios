import Foundation

public enum FAPIJSON {
  public static func normalizeClientJSON(_ data: Data) throws -> Data {
    let object = try JSONSerialization.jsonObject(with: data)
    return try JSONSerialization.data(withJSONObject: replaceNullUserData(object))
  }

  public static func decodeClient(_ data: Data) throws -> Client {
    try JSONDecoder().decode(Client.self, from: normalizeClientJSON(data))
  }

  private static func replaceNullUserData(_ value: Any) -> Any {
    switch value {
    case let object as [String: Any]:
      var normalized: [String: Any] = [:]
      normalized.reserveCapacity(object.count)
      for (key, nested) in object {
        if key == "user_data", nested is NSNull {
          normalized[key] = ["image_url": "", "has_image": false]
        } else {
          normalized[key] = replaceNullUserData(nested)
        }
      }
      return normalized
    case let array as [Any]:
      return array.map(replaceNullUserData)
    default:
      return value
    }
  }
}
