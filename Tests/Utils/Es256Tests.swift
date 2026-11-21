@testable import ClerkKit
import CryptoKit
import Foundation
import Testing

struct Es256Tests {
  @Test
  func thumbprintMatchesTheRfc9449Example() {
    let jwk = Es256PublicJwk(
      xCoordinate: "l8tFrhx-34tV3hRICRDY9zCkDlpBhF42UQUfWVAWBFs",
      yCoordinate: "9VE4jf_Ok_o64zbTTlcuNJajHmt6v9TDVrU0CdvGRDA"
    )

    #expect(jwk.thumbprint == "0ZcOCORZNYy-DWpqq30jZyJGHTN0d2HglBV3uiguA4I")
  }

  @Test
  func publicJwkReadsTheCoordinatesOfAnX963Key() throws {
    let key = P256.Signing.PrivateKey().publicKey

    let jwk = try Es256.publicJwk(fromX963Representation: key.x963Representation)

    let raw = key.rawRepresentation
    #expect(jwk.xCoordinate == Es256.base64URLEncoded(raw.prefix(32)))
    #expect(jwk.yCoordinate == Es256.base64URLEncoded(raw.suffix(32)))
    #expect(jwk.members == ["kty": "EC", "crv": "P-256", "x": jwk.xCoordinate, "y": jwk.yCoordinate, "alg": "ES256"])
  }

  @Test
  func publicJwkRejectsACompressedKey() {
    let compressed = P256.Signing.PrivateKey().publicKey.compressedRepresentation

    #expect(throws: Es256.Failure.invalidPublicKey) {
      try Es256.publicJwk(fromX963Representation: compressed)
    }
  }

  @Test
  func rawSignatureFromDERVerifiesWithCryptoKit() throws {
    let key = P256.Signing.PrivateKey()
    let data = Data("signing input".utf8)
    let der = try key.signature(for: data).derRepresentation

    let raw = try Es256.rawSignature(fromDER: der)

    #expect(raw.count == 64)
    #expect(try key.publicKey.isValidSignature(P256.Signing.ECDSASignature(rawRepresentation: raw), for: data))
  }

  @Test
  func rawSignatureRejectsTrailingBytes() {
    let der = Data([0x30, 0x06, 0x02, 0x01, 0x01, 0x02, 0x01, 0x02, 0x00])

    #expect(throws: Es256.Failure.invalidSignature) {
      try Es256.rawSignature(fromDER: der)
    }
  }
}
