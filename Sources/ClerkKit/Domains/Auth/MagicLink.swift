import Foundation

struct MagicLinkCallback: Equatable {
  let flowId: String
  let approvalToken: String

  init(url: URL) throws {
    guard let flowId = url.queryParam(named: Param.flowId.rawValue) else {
      throw ClerkClientError(message: "Magic link callback is missing flow_id.", localizationBundle: .module)
    }
    guard let approvalToken = url.queryParam(named: Param.approvalToken.rawValue) else {
      throw ClerkClientError(message: "Magic link callback is missing approval_token.", localizationBundle: .module)
    }

    self.flowId = flowId
    self.approvalToken = approvalToken
  }

  private enum Param: String, CaseIterable {
    case flowId = "flow_id"
    case approvalToken = "approval_token"
  }

  static let requiredParams = Set(Param.allCases.map(\.rawValue))
}
