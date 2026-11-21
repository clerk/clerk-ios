//
//  Es256.swift
//  Clerk
//

import CryptoKit
import Foundation

enum Es256 {
  enum Failure: Error, Equatable {
    case invalidSignature
    case invalidPublicKey
  }

  private static let coordinateSize = 32

  static func base64URLEncoded(_ data: some DataProtocol) -> String {
    Data(data)
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  static func publicJwk(fromX963Representation representation: Data) throws -> Es256PublicJwk {
    guard representation.count == 1 + 2 * coordinateSize, representation.first == 0x04 else {
      throw Failure.invalidPublicKey
    }
    let start = representation.startIndex
    let xBytes = representation[(start + 1) ..< (start + 1 + coordinateSize)]
    let yBytes = representation[(start + 1 + coordinateSize) ..< (start + 1 + 2 * coordinateSize)]
    return Es256PublicJwk(xCoordinate: base64URLEncoded(xBytes), yCoordinate: base64URLEncoded(yBytes))
  }

  /// Converts the X9.62 DER signature Security returns into the `r || s` form JWS uses (RFC 7518 §3.4).
  static func rawSignature(fromDER signature: Data) throws -> Data {
    var reader = DERReader(bytes: Array(signature))

    guard try reader.readByte() == 0x30 else { throw Failure.invalidSignature }
    let sequenceLength = try reader.readLength()
    guard sequenceLength == reader.remainingBytes else { throw Failure.invalidSignature }

    let rComponent = try reader.readInteger()
    let sComponent = try reader.readInteger()
    guard reader.remainingBytes == 0 else { throw Failure.invalidSignature }

    var raw = try paddedComponent(rComponent)
    try raw.append(paddedComponent(sComponent))
    return raw
  }

  private static func paddedComponent(_ bytes: [UInt8]) throws -> Data {
    guard let first = bytes.first, first & 0x80 == 0 else { throw Failure.invalidSignature }

    var component = bytes[...]
    while component.first == 0x00, component.count > coordinateSize {
      component = component.dropFirst()
    }
    guard !component.isEmpty, component.count <= coordinateSize else { throw Failure.invalidSignature }

    var padded = Data(repeating: 0x00, count: coordinateSize - component.count)
    padded.append(contentsOf: component)
    return padded
  }

  private struct DERReader {
    let bytes: [UInt8]
    var offset = 0

    var remainingBytes: Int {
      bytes.count - offset
    }

    mutating func readByte() throws -> UInt8 {
      guard offset < bytes.count else { throw Failure.invalidSignature }
      defer { offset += 1 }
      return bytes[offset]
    }

    mutating func readLength() throws -> Int {
      let first = try readByte()
      if first & 0x80 == 0 {
        return Int(first)
      }

      let byteCount = Int(first & 0x7F)
      guard byteCount > 0, byteCount <= MemoryLayout<Int>.size, byteCount <= remainingBytes else {
        throw Failure.invalidSignature
      }

      var length = 0
      for _ in 0 ..< byteCount {
        length = try (length << 8) | Int(readByte())
      }
      return length
    }

    mutating func readInteger() throws -> [UInt8] {
      guard try readByte() == 0x02 else { throw Failure.invalidSignature }
      let length = try readLength()
      guard length > 0, length <= remainingBytes else { throw Failure.invalidSignature }
      defer { offset += length }
      return Array(bytes[offset ..< offset + length])
    }
  }
}

struct Es256PublicJwk: Equatable {
  let xCoordinate: String
  let yCoordinate: String

  var members: [String: String] {
    ["kty": "EC", "crv": "P-256", "x": xCoordinate, "y": yCoordinate, "alg": "ES256"]
  }

  var json: String {
    #"{"kty":"EC","crv":"P-256","x":"\#(xCoordinate)","y":"\#(yCoordinate)","alg":"ES256"}"#
  }

  /// The RFC 7638 thumbprint, which hashes only the required members, in lexicographic order, with no whitespace.
  var thumbprint: String {
    let canonical = #"{"crv":"P-256","kty":"EC","x":"\#(xCoordinate)","y":"\#(yCoordinate)"}"#
    return Es256.base64URLEncoded(Data(SHA256.hash(data: Data(canonical.utf8))))
  }
}
