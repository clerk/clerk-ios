import Foundation

private enum RequestMetadata {
  static let sequenceKey = "com.clerk.request-sequence"
  static let clientSyncDirectiveKey = "com.clerk.client-sync-directive"
}

extension URLRequest {
  mutating func setRequestSequence(_ sequence: UInt64) {
    setProperty(NSNumber(value: sequence), forKey: RequestMetadata.sequenceKey)
  }

  var requestSequence: UInt64? {
    guard let value = URLProtocol.property(forKey: RequestMetadata.sequenceKey, in: self) as? NSNumber else {
      return nil
    }

    return value.uint64Value
  }

  mutating func setClientSyncDirective(_ directive: ClientSyncDirective) {
    setProperty(NSNumber(value: directive.rawValue), forKey: RequestMetadata.clientSyncDirectiveKey)
  }

  var clientSyncDirective: ClientSyncDirective {
    guard
      let rawValue = URLProtocol.property(forKey: RequestMetadata.clientSyncDirectiveKey, in: self) as? NSNumber
    else {
      return .none
    }

    return ClientSyncDirective(rawValue: rawValue.intValue) ?? .none
  }

  private mutating func setProperty(_ value: NSNumber, forKey key: String) {
    guard let mutableRequest = (self as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
      return
    }

    URLProtocol.setProperty(value, forKey: key, in: mutableRequest)

    self = mutableRequest as URLRequest
  }
}
