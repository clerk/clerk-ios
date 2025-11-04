//
//  HTTPURLResponseExtensionsTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct HTTPURLResponseExtensionsTests {

  func createResponse(statusCode: Int) -> HTTPURLResponse? {
    return HTTPURLResponse(
      url: URL(string: "https://example.com")!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    )
  }

  @Test
  func testIsError() {
    // 4xx client errors
    #expect(createResponse(statusCode: 400)?.isError == true)
    #expect(createResponse(statusCode: 404)?.isError == true)
    #expect(createResponse(statusCode: 499)?.isError == true)
    
    // 5xx server errors
    #expect(createResponse(statusCode: 500)?.isError == true)
    #expect(createResponse(statusCode: 503)?.isError == true)
    #expect(createResponse(statusCode: 599)?.isError == true)
    
    // Success codes (should not be errors)
    #expect(createResponse(statusCode: 200)?.isError == false)
    #expect(createResponse(statusCode: 201)?.isError == false)
    #expect(createResponse(statusCode: 299)?.isError == false)
    
    // Redirect codes (should not be errors)
    #expect(createResponse(statusCode: 300)?.isError == false)
    #expect(createResponse(statusCode: 301)?.isError == false)
    #expect(createResponse(statusCode: 399)?.isError == false)
    
    // Informational codes (should not be errors)
    #expect(createResponse(statusCode: 100)?.isError == false)
    #expect(createResponse(statusCode: 199)?.isError == false)
  }

  @Test
  func testIsClientError() {
    // 4xx client errors
    #expect(createResponse(statusCode: 400)?.isClientError == true)
    #expect(createResponse(statusCode: 404)?.isClientError == true)
    #expect(createResponse(statusCode: 499)?.isClientError == true)
    
    // 5xx server errors (should not be client errors)
    #expect(createResponse(statusCode: 500)?.isClientError == false)
    #expect(createResponse(statusCode: 503)?.isClientError == false)
    
    // Success codes
    #expect(createResponse(statusCode: 200)?.isClientError == false)
    
    // Redirect codes
    #expect(createResponse(statusCode: 300)?.isClientError == false)
    
    // Informational codes
    #expect(createResponse(statusCode: 100)?.isClientError == false)
  }

  @Test
  func testIsServerError() {
    // 5xx server errors
    #expect(createResponse(statusCode: 500)?.isServerError == true)
    #expect(createResponse(statusCode: 503)?.isServerError == true)
    #expect(createResponse(statusCode: 599)?.isServerError == true)
    
    // 4xx client errors (should not be server errors)
    #expect(createResponse(statusCode: 400)?.isServerError == false)
    #expect(createResponse(statusCode: 404)?.isServerError == false)
    
    // Success codes
    #expect(createResponse(statusCode: 200)?.isServerError == false)
    
    // Redirect codes
    #expect(createResponse(statusCode: 300)?.isServerError == false)
    
    // Informational codes
    #expect(createResponse(statusCode: 100)?.isServerError == false)
  }

  @Test
  func testIsSuccess() {
    // 2xx success codes
    #expect(createResponse(statusCode: 200)?.isSuccess == true)
    #expect(createResponse(statusCode: 201)?.isSuccess == true)
    #expect(createResponse(statusCode: 204)?.isSuccess == true)
    #expect(createResponse(statusCode: 299)?.isSuccess == true)
    
    // 4xx client errors (should not be success)
    #expect(createResponse(statusCode: 400)?.isSuccess == false)
    
    // 5xx server errors
    #expect(createResponse(statusCode: 500)?.isSuccess == false)
    
    // Redirect codes
    #expect(createResponse(statusCode: 300)?.isSuccess == false)
    
    // Informational codes
    #expect(createResponse(statusCode: 100)?.isSuccess == false)
  }

  @Test
  func testIsRedirection() {
    // 3xx redirect codes
    #expect(createResponse(statusCode: 300)?.isRedirection == true)
    #expect(createResponse(statusCode: 301)?.isRedirection == true)
    #expect(createResponse(statusCode: 302)?.isRedirection == true)
    #expect(createResponse(statusCode: 399)?.isRedirection == true)
    
    // 2xx success codes (should not be redirects)
    #expect(createResponse(statusCode: 200)?.isRedirection == false)
    
    // 4xx client errors
    #expect(createResponse(statusCode: 400)?.isRedirection == false)
    
    // 5xx server errors
    #expect(createResponse(statusCode: 500)?.isRedirection == false)
    
    // Informational codes
    #expect(createResponse(statusCode: 100)?.isRedirection == false)
  }

  @Test
  func testStatusType() {
    // Informational (1xx)
    #expect(createResponse(statusCode: 100)?.statusType == .informational)
    #expect(createResponse(statusCode: 199)?.statusType == .informational)
    
    // Success (2xx)
    #expect(createResponse(statusCode: 200)?.statusType == .success)
    #expect(createResponse(statusCode: 299)?.statusType == .success)
    
    // Redirection (3xx)
    #expect(createResponse(statusCode: 300)?.statusType == .redirection)
    #expect(createResponse(statusCode: 399)?.statusType == .redirection)
    
    // Client Error (4xx)
    #expect(createResponse(statusCode: 400)?.statusType == .clientError)
    #expect(createResponse(statusCode: 499)?.statusType == .clientError)
    
    // Server Error (5xx)
    #expect(createResponse(statusCode: 500)?.statusType == .serverError)
    #expect(createResponse(statusCode: 599)?.statusType == .serverError)
    
    // Unknown (outside normal range)
    #expect(createResponse(statusCode: 0)?.statusType == .unknown)
    #expect(createResponse(statusCode: 99)?.statusType == .unknown)
    #expect(createResponse(statusCode: 600)?.statusType == .unknown)
    #expect(createResponse(statusCode: 999)?.statusType == .unknown)
  }

  @Test
  func testStatusDescription() {
    // Informational
    let infoResponse = createResponse(statusCode: 100)!
    #expect(infoResponse.statusDescription.contains("Informational"))
    #expect(infoResponse.statusDescription.contains("100"))
    
    // Success
    let successResponse = createResponse(statusCode: 200)!
    #expect(successResponse.statusDescription.contains("Success"))
    #expect(successResponse.statusDescription.contains("200"))
    
    // Redirection
    let redirectResponse = createResponse(statusCode: 301)!
    #expect(redirectResponse.statusDescription.contains("Redirection"))
    #expect(redirectResponse.statusDescription.contains("301"))
    
    // Client Error
    let clientErrorResponse = createResponse(statusCode: 404)!
    #expect(clientErrorResponse.statusDescription.contains("Client Error"))
    #expect(clientErrorResponse.statusDescription.contains("404"))
    
    // Server Error
    let serverErrorResponse = createResponse(statusCode: 500)!
    #expect(serverErrorResponse.statusDescription.contains("Server Error"))
    #expect(serverErrorResponse.statusDescription.contains("500"))
    
    // Unknown
    let unknownResponse = createResponse(statusCode: 999)!
    #expect(unknownResponse.statusDescription.contains("Unknown Status"))
    #expect(unknownResponse.statusDescription.contains("999"))
  }
}

