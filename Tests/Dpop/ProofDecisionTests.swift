@testable import ClerkKit
import Foundation
import Testing

struct ProofDecisionTests {
  struct Case: CustomTestStringConvertible, Sendable {
    let tokenHasCnf: Bool
    let binding: DeviceBinding
    let signFailure: SignFailure?
    let expected: ProofDecision

    var testDescription: String {
      "cnf=\(tokenHasCnf) \(binding) failure=\(String(describing: signFailure)) -> \(expected)"
    }
  }

  static let cases: [Case] = [
    Case(tokenHasCnf: false, binding: .signing, signFailure: nil, expected: .sign),
    Case(tokenHasCnf: true, binding: .signing, signFailure: nil, expected: .sign),
    Case(tokenHasCnf: false, binding: .signing, signFailure: .notALoss, expected: .sendUnsigned),
    Case(tokenHasCnf: true, binding: .signing, signFailure: .notALoss, expected: .failRequest(.keyError)),
    Case(tokenHasCnf: false, binding: .signing, signFailure: .keyLost, expected: .sendUnsigned),
    Case(tokenHasCnf: true, binding: .signing, signFailure: .keyLost, expected: .sendUnsigned),
    Case(tokenHasCnf: false, binding: .notSigning(.sharedToken), signFailure: nil, expected: .sendUnsigned),
    Case(tokenHasCnf: true, binding: .notSigning(.sharedToken), signFailure: nil, expected: .sendUnsigned),
    Case(tokenHasCnf: false, binding: .notSigning(.keyUnavailable), signFailure: nil, expected: .sendUnsigned),
    Case(tokenHasCnf: true, binding: .notSigning(.keyUnavailable), signFailure: nil, expected: .sendUnsigned),
    Case(tokenHasCnf: false, binding: .notSigning(.timeout), signFailure: nil, expected: .sendUnsigned),
    Case(tokenHasCnf: true, binding: .notSigning(.timeout), signFailure: nil, expected: .failRequest(.keyNotReady)),
  ]

  @Test(arguments: cases)
  func decidesWhetherARequestCarriesAProof(_ testCase: Case) {
    #expect(proofDecision(
      tokenHasCnf: testCase.tokenHasCnf,
      binding: testCase.binding,
      signFailure: testCase.signFailure
    ) == testCase.expected)
  }

  @Test
  func aTokenIsDeviceBoundWhenItCarriesCnf() throws {
    #expect(try DeviceTokenClaims.hasCnf(testJWT(claims: ["id": "client_1", "cnf": ["jkt": "thumbprint"]])))
    #expect(try !DeviceTokenClaims.hasCnf(testJWT(claims: ["id": "client_1"])))
    #expect(!DeviceTokenClaims.hasCnf("not-a-jwt"))
  }
}
