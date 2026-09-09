import ClerkKit

struct PasskeyAuthenticationFailure: Error {
  enum Stage: String {
    case preparingFirstFactor
    case preparingSecondFactor
    case requestingAuthorization
    case attemptingFirstFactor
    case attemptingSecondFactor
    case unknown
  }

  let stage: Stage
  let underlyingError: any Error

  init(_ error: any Error) {
    underlyingError = error
    stage = (error as? CoreError)?.passkeyStage.flatMap(Stage.init(rawValue:)) ?? .unknown
  }
}
