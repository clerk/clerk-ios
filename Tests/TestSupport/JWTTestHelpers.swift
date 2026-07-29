import Foundation

func testJWT(
  header: [String: Any] = ["alg": "none", "typ": "JWT"],
  claims: [String: Any],
  signature: String = "signature"
) throws -> String {
  try [
    base64URLEncodedJSON(header),
    base64URLEncodedJSON(claims),
    signature,
  ].joined(separator: ".")
}

private func base64URLEncodedJSON(_ object: [String: Any]) throws -> String {
  try JSONSerialization.data(withJSONObject: object)
    .base64EncodedString()
    .replacingOccurrences(of: "+", with: "-")
    .replacingOccurrences(of: "/", with: "_")
    .replacingOccurrences(of: "=", with: "")
}
