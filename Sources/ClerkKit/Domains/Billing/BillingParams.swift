//
//  BillingParams.swift
//  Clerk
//

import Foundation

/// The payer type of a Billing Plan.
public enum ForPayerType: String, Codable, Equatable, Sendable {
  case organization
  case user
}

package struct GetPlansParams: Equatable {
  package var `for`: ForPayerType
  package var orgId: String?
  package var minSeats: Int?
  package var page: Int
  package var pageSize: Int

  package init(
    for: ForPayerType = .user,
    orgId: String? = nil,
    minSeats: Int? = nil,
    page: Int = 1,
    pageSize: Int = 20
  ) {
    self.for = `for`
    self.orgId = orgId
    self.minSeats = minSeats
    self.page = page
    self.pageSize = pageSize
  }
}

package struct GetPlanParams: Equatable {
  package var id: String

  package init(id: String) {
    self.id = id
  }
}

package struct GetSubscriptionParams: Equatable {
  package var orgId: String?

  package init(orgId: String? = nil) {
    self.orgId = orgId
  }
}

package struct GetStatementsParams: Equatable {
  package var orgId: String?
  package var page: Int
  package var pageSize: Int

  package init(orgId: String? = nil, page: Int = 1, pageSize: Int = 20) {
    self.orgId = orgId
    self.page = page
    self.pageSize = pageSize
  }
}

package struct GetStatementParams: Equatable {
  package var id: String
  package var orgId: String?

  package init(id: String, orgId: String? = nil) {
    self.id = id
    self.orgId = orgId
  }
}

package struct GetPaymentAttemptsParams: Equatable {
  package var orgId: String?
  package var page: Int
  package var pageSize: Int

  package init(orgId: String? = nil, page: Int = 1, pageSize: Int = 20) {
    self.orgId = orgId
    self.page = page
    self.pageSize = pageSize
  }
}

package struct GetPaymentAttemptParams: Equatable {
  package var id: String
  package var orgId: String?

  package init(id: String, orgId: String? = nil) {
    self.id = id
    self.orgId = orgId
  }
}

package struct GetCreditBalanceParams: Equatable {
  package var orgId: String?

  package init(orgId: String? = nil) {
    self.orgId = orgId
  }
}

package struct GetCreditHistoryParams: Equatable {
  package var orgId: String?
  package var page: Int
  package var pageSize: Int

  package init(orgId: String? = nil, page: Int = 1, pageSize: Int = 20) {
    self.orgId = orgId
    self.page = page
    self.pageSize = pageSize
  }
}

package struct GetPaymentMethodsParams: Equatable {
  package var page: Int
  package var pageSize: Int

  package init(page: Int = 1, pageSize: Int = 20) {
    self.page = page
    self.pageSize = pageSize
  }
}
