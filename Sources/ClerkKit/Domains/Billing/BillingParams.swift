//
//  BillingParams.swift
//  Clerk
//

import Foundation

public enum ForPayerType: String, Codable, Equatable, Sendable {
  case organization
  case user
}

public struct GetPlansParams: Equatable, Sendable {
  public var `for`: ForPayerType?
  public var orgId: String?
  public var minSeats: Int?
  public var initialPage: Int?
  public var pageSize: Int?

  public init(
    for: ForPayerType? = nil,
    orgId: String? = nil,
    minSeats: Int? = nil,
    initialPage: Int? = nil,
    pageSize: Int? = nil
  ) {
    self.for = `for`
    self.orgId = orgId
    self.minSeats = minSeats
    self.initialPage = initialPage
    self.pageSize = pageSize
  }
}

public struct GetPlanParams: Equatable, Sendable {
  public var id: String

  public init(id: String) {
    self.id = id
  }
}

public struct GetSubscriptionParams: Equatable, Sendable {
  public var orgId: String?

  public init(orgId: String? = nil) {
    self.orgId = orgId
  }
}

public struct GetStatementsParams: Equatable, Sendable {
  public var orgId: String?
  public var initialPage: Int?
  public var pageSize: Int?

  public init(
    orgId: String? = nil,
    initialPage: Int? = nil,
    pageSize: Int? = nil
  ) {
    self.orgId = orgId
    self.initialPage = initialPage
    self.pageSize = pageSize
  }
}

public struct GetStatementParams: Equatable, Sendable {
  public var id: String
  public var orgId: String?
  public var initialPage: Int?
  public var pageSize: Int?

  public init(
    id: String,
    orgId: String? = nil,
    initialPage: Int? = nil,
    pageSize: Int? = nil
  ) {
    self.id = id
    self.orgId = orgId
    self.initialPage = initialPage
    self.pageSize = pageSize
  }
}

public struct GetPaymentAttemptsParams: Equatable, Sendable {
  public var orgId: String?
  public var initialPage: Int?
  public var pageSize: Int?

  public init(
    orgId: String? = nil,
    initialPage: Int? = nil,
    pageSize: Int? = nil
  ) {
    self.orgId = orgId
    self.initialPage = initialPage
    self.pageSize = pageSize
  }
}

public struct GetPaymentAttemptParams: Equatable, Sendable {
  public var id: String
  public var orgId: String?
  public var initialPage: Int?
  public var pageSize: Int?

  public init(
    id: String,
    orgId: String? = nil,
    initialPage: Int? = nil,
    pageSize: Int? = nil
  ) {
    self.id = id
    self.orgId = orgId
    self.initialPage = initialPage
    self.pageSize = pageSize
  }
}

public struct GetCreditBalanceParams: Equatable, Sendable {
  public var orgId: String?

  public init(orgId: String? = nil) {
    self.orgId = orgId
  }
}

public struct GetCreditHistoryParams: Equatable, Sendable {
  public var orgId: String?

  public init(orgId: String? = nil) {
    self.orgId = orgId
  }
}

public struct GetPaymentMethodsParams: Equatable, Sendable {
  public var initialPage: Int?
  public var pageSize: Int?

  public init(
    initialPage: Int? = nil,
    pageSize: Int? = nil
  ) {
    self.initialPage = initialPage
    self.pageSize = pageSize
  }
}
