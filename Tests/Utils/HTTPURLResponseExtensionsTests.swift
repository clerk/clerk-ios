//
//  HTTPURLResponseExtensionsTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct HTTPURLResponseExtensionsTests {
  func createResponse(statusCode: Int) -> HTTPURLResponse? {
    HTTPURLResponse(
      url: URL(string: "https://example.com")!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    )
  }

  @Test
  func testIsError() {
    #expect(createResponse(statusCode: 400)?.isError == true)
    #expect(createResponse(statusCode: 404)?.isError == true)
    #expect(createResponse(statusCode: 499)?.isError == true)

    #expect(createResponse(statusCode: 500)?.isError == true)
    #expect(createResponse(statusCode: 503)?.isError == true)
    #expect(createResponse(statusCode: 599)?.isError == true)

    #expect(createResponse(statusCode: 200)?.isError == false)
    #expect(createResponse(statusCode: 201)?.isError == false)
    #expect(createResponse(statusCode: 299)?.isError == false)

    #expect(createResponse(statusCode: 300)?.isError == false)
    #expect(createResponse(statusCode: 301)?.isError == false)
    #expect(createResponse(statusCode: 399)?.isError == false)

    #expect(createResponse(statusCode: 100)?.isError == false)
    #expect(createResponse(statusCode: 199)?.isError == false)
  }

  @Test
  func testIsClientError() {
    #expect(createResponse(statusCode: 400)?.isClientError == true)
    #expect(createResponse(statusCode: 404)?.isClientError == true)
    #expect(createResponse(statusCode: 499)?.isClientError == true)

    #expect(createResponse(statusCode: 500)?.isClientError == false)
    #expect(createResponse(statusCode: 503)?.isClientError == false)

    #expect(createResponse(statusCode: 200)?.isClientError == false)

    #expect(createResponse(statusCode: 300)?.isClientError == false)

    #expect(createResponse(statusCode: 100)?.isClientError == false)
  }

  @Test
  func testIsServerError() {
    #expect(createResponse(statusCode: 500)?.isServerError == true)
    #expect(createResponse(statusCode: 503)?.isServerError == true)
    #expect(createResponse(statusCode: 599)?.isServerError == true)

    #expect(createResponse(statusCode: 400)?.isServerError == false)
    #expect(createResponse(statusCode: 404)?.isServerError == false)

    #expect(createResponse(statusCode: 200)?.isServerError == false)

    #expect(createResponse(statusCode: 300)?.isServerError == false)

    #expect(createResponse(statusCode: 100)?.isServerError == false)
  }

  @Test
  func testIsSuccess() {
    #expect(createResponse(statusCode: 200)?.isSuccess == true)
    #expect(createResponse(statusCode: 201)?.isSuccess == true)
    #expect(createResponse(statusCode: 204)?.isSuccess == true)
    #expect(createResponse(statusCode: 299)?.isSuccess == true)

    #expect(createResponse(statusCode: 400)?.isSuccess == false)

    #expect(createResponse(statusCode: 500)?.isSuccess == false)

    #expect(createResponse(statusCode: 300)?.isSuccess == false)

    #expect(createResponse(statusCode: 100)?.isSuccess == false)
  }

  @Test
  func testIsRedirection() {
    #expect(createResponse(statusCode: 300)?.isRedirection == true)
    #expect(createResponse(statusCode: 301)?.isRedirection == true)
    #expect(createResponse(statusCode: 302)?.isRedirection == true)
    #expect(createResponse(statusCode: 399)?.isRedirection == true)

    #expect(createResponse(statusCode: 200)?.isRedirection == false)

    #expect(createResponse(statusCode: 400)?.isRedirection == false)

    #expect(createResponse(statusCode: 500)?.isRedirection == false)

    #expect(createResponse(statusCode: 100)?.isRedirection == false)
  }

  @Test
  func testStatusType() {
    #expect(createResponse(statusCode: 100)?.statusType == .informational)
    #expect(createResponse(statusCode: 199)?.statusType == .informational)

    #expect(createResponse(statusCode: 200)?.statusType == .success)
    #expect(createResponse(statusCode: 299)?.statusType == .success)

    #expect(createResponse(statusCode: 300)?.statusType == .redirection)
    #expect(createResponse(statusCode: 399)?.statusType == .redirection)

    #expect(createResponse(statusCode: 400)?.statusType == .clientError)
    #expect(createResponse(statusCode: 499)?.statusType == .clientError)

    #expect(createResponse(statusCode: 500)?.statusType == .serverError)
    #expect(createResponse(statusCode: 599)?.statusType == .serverError)

    #expect(createResponse(statusCode: 0)?.statusType == .unknown)
    #expect(createResponse(statusCode: 99)?.statusType == .unknown)
    #expect(createResponse(statusCode: 600)?.statusType == .unknown)
    #expect(createResponse(statusCode: 999)?.statusType == .unknown)
  }

  @Test
  func testStatusDescription() throws {
    let infoResponse = try #require(createResponse(statusCode: 100))
    #expect(infoResponse.statusDescription.contains("Informational"))
    #expect(infoResponse.statusDescription.contains("100"))

    let successResponse = try #require(createResponse(statusCode: 200))
    #expect(successResponse.statusDescription.contains("Success"))
    #expect(successResponse.statusDescription.contains("200"))

    let redirectResponse = try #require(createResponse(statusCode: 301))
    #expect(redirectResponse.statusDescription.contains("Redirection"))
    #expect(redirectResponse.statusDescription.contains("301"))

    let clientErrorResponse = try #require(createResponse(statusCode: 404))
    #expect(clientErrorResponse.statusDescription.contains("Client Error"))
    #expect(clientErrorResponse.statusDescription.contains("404"))

    let serverErrorResponse = try #require(createResponse(statusCode: 500))
    #expect(serverErrorResponse.statusDescription.contains("Server Error"))
    #expect(serverErrorResponse.statusDescription.contains("500"))

    let unknownResponse = try #require(createResponse(statusCode: 999))
    #expect(unknownResponse.statusDescription.contains("Unknown Status"))
    #expect(unknownResponse.statusDescription.contains("999"))
  }
}
