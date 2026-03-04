import Foundation

private enum RequestSequenceMetadata {
  static let key = "com.clerk.request-sequence"
}

extension URLRequest {
  mutating func setRequestSequence(_ sequence: UInt64) {
    guard let mutableRequest = (self as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
      return
    }

    URLProtocol.setProperty(
      NSNumber(value: sequence),
      forKey: RequestSequenceMetadata.key,
      in: mutableRequest
    )

    self = mutableRequest as URLRequest
  }

  var requestSequence: UInt64? {
    guard let value = URLProtocol.property(forKey: RequestSequenceMetadata.key, in: self) as? NSNumber else {
      return nil
    }

    return value.uint64Value
  }
}
