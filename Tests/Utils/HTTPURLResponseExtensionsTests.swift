//
//  HTTPURLResponseExtensionsTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.tags(.unit))
struct HTTPURLResponseExtensionsTests {
  struct ClassificationScenario {
    let statusCode: Int
    let isError: Bool
    let isClientError: Bool
    let isServerError: Bool
    let isSuccess: Bool
    let isRedirection: Bool
    let statusType: HTTPStatusType
  }

  struct StatusDescriptionScenario {
    let statusCode: Int
    let expectedCategory: String
  }

  func createResponse(statusCode: Int) -> HTTPURLResponse? {
    HTTPURLResponse(
      url: URL(string: "https://example.com")!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    )
  }

  @Test(arguments: Self.classificationScenarios)
  func responseClassificationMatchesExpectedValues(for scenario: ClassificationScenario) throws {
    let response = try #require(createResponse(statusCode: scenario.statusCode))

    #expect(response.isError == scenario.isError)
    #expect(response.isClientError == scenario.isClientError)
    #expect(response.isServerError == scenario.isServerError)
    #expect(response.isSuccess == scenario.isSuccess)
    #expect(response.isRedirection == scenario.isRedirection)
    #expect(response.statusType == scenario.statusType)
  }

  @Test(arguments: Self.statusDescriptionScenarios)
  func statusDescriptionIncludesCategoryAndCode(for scenario: StatusDescriptionScenario) throws {
    let response = try #require(createResponse(statusCode: scenario.statusCode))

    #expect(response.statusDescription.contains(scenario.expectedCategory))
    #expect(response.statusDescription.contains(String(scenario.statusCode)))
  }

  private static let classificationScenarios: [ClassificationScenario] = [
    .init(statusCode: 0, isError: false, isClientError: false, isServerError: false, isSuccess: false, isRedirection: false, statusType: .unknown),
    .init(statusCode: 99, isError: false, isClientError: false, isServerError: false, isSuccess: false, isRedirection: false, statusType: .unknown),
    .init(statusCode: 100, isError: false, isClientError: false, isServerError: false, isSuccess: false, isRedirection: false, statusType: .informational),
    .init(statusCode: 199, isError: false, isClientError: false, isServerError: false, isSuccess: false, isRedirection: false, statusType: .informational),
    .init(statusCode: 200, isError: false, isClientError: false, isServerError: false, isSuccess: true, isRedirection: false, statusType: .success),
    .init(statusCode: 201, isError: false, isClientError: false, isServerError: false, isSuccess: true, isRedirection: false, statusType: .success),
    .init(statusCode: 204, isError: false, isClientError: false, isServerError: false, isSuccess: true, isRedirection: false, statusType: .success),
    .init(statusCode: 299, isError: false, isClientError: false, isServerError: false, isSuccess: true, isRedirection: false, statusType: .success),
    .init(statusCode: 300, isError: false, isClientError: false, isServerError: false, isSuccess: false, isRedirection: true, statusType: .redirection),
    .init(statusCode: 301, isError: false, isClientError: false, isServerError: false, isSuccess: false, isRedirection: true, statusType: .redirection),
    .init(statusCode: 302, isError: false, isClientError: false, isServerError: false, isSuccess: false, isRedirection: true, statusType: .redirection),
    .init(statusCode: 399, isError: false, isClientError: false, isServerError: false, isSuccess: false, isRedirection: true, statusType: .redirection),
    .init(statusCode: 400, isError: true, isClientError: true, isServerError: false, isSuccess: false, isRedirection: false, statusType: .clientError),
    .init(statusCode: 404, isError: true, isClientError: true, isServerError: false, isSuccess: false, isRedirection: false, statusType: .clientError),
    .init(statusCode: 499, isError: true, isClientError: true, isServerError: false, isSuccess: false, isRedirection: false, statusType: .clientError),
    .init(statusCode: 500, isError: true, isClientError: false, isServerError: true, isSuccess: false, isRedirection: false, statusType: .serverError),
    .init(statusCode: 503, isError: true, isClientError: false, isServerError: true, isSuccess: false, isRedirection: false, statusType: .serverError),
    .init(statusCode: 599, isError: true, isClientError: false, isServerError: true, isSuccess: false, isRedirection: false, statusType: .serverError),
    .init(statusCode: 600, isError: true, isClientError: false, isServerError: true, isSuccess: false, isRedirection: false, statusType: .unknown),
    .init(statusCode: 999, isError: true, isClientError: false, isServerError: true, isSuccess: false, isRedirection: false, statusType: .unknown),
  ]

  private static let statusDescriptionScenarios: [StatusDescriptionScenario] = [
    .init(statusCode: 100, expectedCategory: "Informational"),
    .init(statusCode: 200, expectedCategory: "Success"),
    .init(statusCode: 301, expectedCategory: "Redirection"),
    .init(statusCode: 404, expectedCategory: "Client Error"),
    .init(statusCode: 500, expectedCategory: "Server Error"),
    .init(statusCode: 999, expectedCategory: "Unknown Status"),
  ]
}
