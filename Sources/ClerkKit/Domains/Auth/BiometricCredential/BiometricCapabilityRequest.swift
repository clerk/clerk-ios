import Foundation

enum BiometricCapabilityRequest: Decodable {
  case context
  case candidates(id: String?, identifierHint: String?, userID: String?)
  case records
  case createKey(BiometricCredentialPolicy)
  case sign(clientData: String, localKeyId: String, reason: String?)
  case save(BiometricCredentialLocalRecord)
  case remove(BiometricCredentialLocalRecord)
  case removeById(String)
  case deleteKey(String)
  case dispose

  var requiresCurrentIdentity: Bool {
    switch self {
    case .deleteKey, .dispose: false
    default: true
    }
  }

  private enum CodingKeys: String, CodingKey {
    case operation, id, identifierHint, userID, localKeyId, clientData, reason, policy, credential
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    func required<T: Decodable>(_ type: T.Type, _ key: CodingKeys) throws -> T {
      guard let value = try container.decodeIfPresent(type, forKey: key) else {
        throw ClerkClientError(message: "Missing biometric capability argument.")
      }
      return value
    }
    switch try container.decode(String.self, forKey: .operation) {
    case "context": self = .context
    case "candidates":
      self = try .candidates(
        id: container.decodeIfPresent(String.self, forKey: .id),
        identifierHint: container.decodeIfPresent(String.self, forKey: .identifierHint),
        userID: container.decodeIfPresent(String.self, forKey: .userID)
      )
    case "records": self = .records
    case "createKey": self = try .createKey(required(BiometricCredentialPolicy.self, .policy))
    case "sign":
      self = try .sign(
        clientData: required(String.self, .clientData),
        localKeyId: required(String.self, .localKeyId),
        reason: container.decodeIfPresent(String.self, forKey: .reason)
      )
    case "save": self = try .save(required(BiometricCredentialLocalRecord.self, .credential))
    case "remove": self = try .remove(required(BiometricCredentialLocalRecord.self, .credential))
    case "removeById": self = try .removeById(required(String.self, .id))
    case "deleteKey": self = try .deleteKey(required(String.self, .localKeyId))
    case "dispose": self = .dispose
    default: throw ClerkClientError(message: "Unknown biometric capability operation.")
    }
  }
}
