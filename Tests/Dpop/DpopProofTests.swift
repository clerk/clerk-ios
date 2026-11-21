@testable import ClerkKit
import CryptoKit
import Foundation
import Security
import Testing

struct DpopProofTests {
  private let key = InMemoryDeviceKey(privateKey: P256.Signing.PrivateKey())
  private let now = Date(timeIntervalSince1970: 1_763_400_000.75)
  private let request = DpopBoundRequest(
    method: "POST",
    url: URL(string: "https://clerk.example.com/v1/client/sign_ins?_is_native=true#top")!,
    accessToken: "Kz~8mXK1EalYznwH-LC-1fBAo.4Ljp~zsPE_NeO.gxU"
  )

  @Test
  func headerNamesTheTypeTheAlgorithmAndThePublicKey() throws {
    let proof = try DpopProof.build(key: key, request: request, now: now, jti: "jti-1")

    let header = try part(0, of: proof)
    #expect(header["typ"] as? String == "dpop+jwt")
    #expect(header["alg"] as? String == "ES256")
    #expect(header["jwk"] as? [String: String] == key.publicJwk.members)
    #expect(header.count == 3)
  }

  @Test
  func payloadBindsTheRequestTheTimeAndTheKeyLevel() throws {
    let proof = try DpopProof.build(key: key, request: request, now: now, jti: "jti-1")

    let payload = try part(1, of: proof)
    #expect(payload["jti"] as? String == "jti-1")
    #expect(payload["htm"] as? String == "POST")
    #expect(payload["htu"] as? String == "https://clerk.example.com/v1/client/sign_ins")
    #expect(payload["iat"] as? Int == 1_763_400_000)
    #expect(payload["ath"] as? String == "fUHyO2r2Z3DZ53EsNrWBb0xWXoaNy59IiKCAqksmQEo")
    #expect(payload["clerk_sl"] as? String == "software")
    #expect(payload.count == 6)
  }

  @Test
  func aRequestWithoutATokenHasNoAth() throws {
    let unauthenticated = DpopBoundRequest(method: "GET", url: request.url, accessToken: nil)

    let payload = try part(1, of: DpopProof.build(key: key, request: unauthenticated, now: now, jti: "jti-1"))

    #expect(payload["ath"] == nil)
  }

  @Test
  func signatureVerifiesWithSecurityAgainstTheHeaderKey() throws {
    let proof = try DpopProof.build(key: key, request: request, now: now, jti: "jti-1")
    let parts = proof.split(separator: ".").map(String.init)
    let jwk = try #require(part(0, of: proof)["jwk"] as? [String: String])
    let x = try #require(jwk["x"]?.dataFromBase64URL())
    let y = try #require(jwk["y"]?.dataFromBase64URL())
    let publicKey = try #require(SecKeyCreateWithData(
      (Data([0x04]) + x + y) as CFData,
      [
        kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
        kSecAttrKeyClass: kSecAttrKeyClassPublic,
      ] as CFDictionary,
      nil
    ))
    let raw = try #require(parts[2].dataFromBase64URL())
    let der = try P256.Signing.ECDSASignature(rawRepresentation: raw).derRepresentation

    #expect(SecKeyVerifySignature(
      publicKey,
      .ecdsaSignatureMessageX962SHA256,
      Data("\(parts[0]).\(parts[1])".utf8) as CFData,
      der as CFData,
      nil
    ))
  }

  @Test
  func htuDropsTheUserInfo() throws {
    let url = try #require(URL(string: "https://user:secret@clerk.example.com:8443/v1/client?a=1"))

    #expect(try DpopProof.htu(url) == "https://clerk.example.com:8443/v1/client")
  }

  @Test
  func htuKeepsAProxyPath() throws {
    let url = try #require(URL(string: "https://app.example.com/__clerk/v1/environment?_is_native=true"))

    #expect(try DpopProof.htu(url) == "https://app.example.com/__clerk/v1/environment")
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["CLERK_DPOP_PROOF_OUT"] != nil))
  func writesAProofForClerkGosVerifier() throws {
    let out = try #require(ProcessInfo.processInfo.environment["CLERK_DPOP_PROOF_OUT"])
    let proof = try DpopProof.build(
      key: key,
      request: DpopBoundRequest(
        method: "GET",
        url: #require(URL(string: "https://clerk.prod.lclclerk.com/v1/client?_is_native=true")),
        accessToken: "client-token"
      ),
      now: .now,
      jti: UUID().uuidString
    )
    let fixture = ["proof": proof, "thumbprint": key.thumbprint]
    try JSONSerialization.data(withJSONObject: fixture).write(to: URL(fileURLWithPath: out))
  }

  private func part(_ index: Int, of proof: String) throws -> [String: Any] {
    let segment = String(proof.split(separator: ".")[index])
    let data = try #require(segment.dataFromBase64URL())
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }
}
