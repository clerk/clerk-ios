//
//  BillingCreditLedger.swift
//  Clerk
//

import Foundation

public struct BillingCreditLedger: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var amount: BillingMoneyAmount
  public var sourceType: String
  public var sourceId: String
  public var createdAt: Date

  public init(
    id: String,
    amount: BillingMoneyAmount,
    sourceType: String,
    sourceId: String,
    createdAt: Date
  ) {
    self.id = id
    self.amount = amount
    self.sourceType = sourceType
    self.sourceId = sourceId
    self.createdAt = createdAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    amount = try container.decode(BillingMoneyAmount.self, forKey: .amount)
    sourceType = try container.decode(String.self, forKey: .sourceType)
    sourceId = try container.decode(String.self, forKey: .sourceId)

    // FAPI serializes this field as an RFC 3339 string, unlike the epoch
    // milliseconds used by the other billing resources.
    if let rawCreatedAt = try? container.decode(String.self, forKey: .createdAt) {
      guard let date = Self.date(fromRFC3339: rawCreatedAt) else {
        throw DecodingError.dataCorruptedError(
          forKey: .createdAt,
          in: container,
          debugDescription: "Expected an RFC 3339 date string, found \"\(rawCreatedAt)\"."
        )
      }
      createdAt = date
    } else {
      createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
  }

  private static func date(fromRFC3339 value: String) -> Date? {
    (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value))
      ?? (try? Date.ISO8601FormatStyle().parse(value))
  }
}
