//
//  JWTDecoderTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct JWTDecoderTests {

  // Helper to create a valid JWT for testing
  func createTestJWT(header: [String: Any] = ["alg": "HS256", "typ": "JWT"],
                     body: [String: Any]) -> String {
    let headerJSON = try! JSONSerialization.data(withJSONObject: header)
    let bodyJSON = try! JSONSerialization.data(withJSONObject: body)
    
    let headerBase64 = headerJSON.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    
    let bodyBase64 = bodyJSON.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    
    return "\(headerBase64).\(bodyBase64).signature"
  }

  @Test
  func testDecodeValidJWT() throws {
    let body: [String: Any] = [
      "sub": "user123",
      "iss": "https://example.com",
      "exp": 1609459200
    ]
    let jwtString = createTestJWT(body: body)
    
    let jwt = try decode(jwt: jwtString)
    
    #expect(jwt.subject == "user123")
    #expect(jwt.issuer == "https://example.com")
    #expect(jwt.expiresAt != nil)
  }

  @Test
  func testJWTDecodeErrorInvalidPartCount() {
    // JWT with only 2 parts
    do {
      _ = try decode(jwt: "header.body")
      Issue.record("Expected invalidPartCount error")
    } catch let error as JWTDecodeError {
      if case .invalidPartCount = error {
        // Expected error
      } else {
        Issue.record("Wrong error type")
      }
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
    
    // JWT with 4 parts
    do {
      _ = try decode(jwt: "header.body.signature.extra")
      Issue.record("Expected invalidPartCount error")
    } catch let error as JWTDecodeError {
      if case .invalidPartCount = error {
        // Expected error
      } else {
        Issue.record("Wrong error type")
      }
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
    
    // JWT with no parts
    do {
      _ = try decode(jwt: "invalid")
      Issue.record("Expected invalidPartCount error")
    } catch let error as JWTDecodeError {
      if case .invalidPartCount = error {
        // Expected error
      } else {
        Issue.record("Wrong error type")
      }
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func testJWTDecodeErrorInvalidBase64URL() {
    let invalidBase64 = "!!!.body.signature"
    
    do {
      _ = try decode(jwt: invalidBase64)
      Issue.record("Expected invalidBase64URL error")
    } catch let error as JWTDecodeError {
      if case .invalidBase64URL = error {
        // Expected error
      } else {
        Issue.record("Wrong error type")
      }
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func testJWTDecodeErrorInvalidJSON() {
    // Create invalid JSON in body
    let invalidBody = "not_valid_json"
    let bodyBase64 = invalidBody.data(using: .utf8)!.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    
    let headerBase64 = try! JSONSerialization.data(withJSONObject: ["alg": "HS256"])
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    
    let invalidJWT = "\(headerBase64).\(bodyBase64).signature"
    
    do {
      _ = try decode(jwt: invalidJWT)
      Issue.record("Expected invalidJSON error")
    } catch let error as JWTDecodeError {
      if case .invalidJSON = error {
        // Expected error
      } else {
        Issue.record("Wrong error type")
      }
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func testJWTClaimExtraction() throws {
    let body: [String: Any] = [
      "sub": "user123",
      "iss": "https://example.com",
      "aud": ["audience1", "audience2"],
      "exp": 1609459200,
      "iat": 1609455600,
      "nbf": 1609455800,
      "jti": "token123"
    ]
    let jwtString = createTestJWT(body: body)
    let jwt = try decode(jwt: jwtString)
    
    #expect(jwt.subject == "user123")
    #expect(jwt.issuer == "https://example.com")
    #expect(jwt.audience == ["audience1", "audience2"])
    #expect(jwt.expiresAt != nil)
    #expect(jwt.issuedAt != nil)
    #expect(jwt.notBefore != nil)
    #expect(jwt.identifier == "token123")
  }

  @Test
  func testJWTExpired() throws {
    // Expired JWT (exp is in the past)
    let pastExp = Date().timeIntervalSince1970 - 1000
    let expiredBody: [String: Any] = ["exp": pastExp]
    let expiredJWT = createTestJWT(body: expiredBody)
    let expired = try decode(jwt: expiredJWT)
    
    #expect(expired.expired == true)
    
    // Future exp (not expired)
    let futureExp = Date().timeIntervalSince1970 + 1000
    let validBody: [String: Any] = ["exp": futureExp]
    let validJWT = createTestJWT(body: validBody)
    let valid = try decode(jwt: validJWT)
    
    #expect(valid.expired == false)
    
    // No exp claim (not expired)
    let noExpBody: [String: Any] = ["sub": "user123"]
    let noExpJWT = createTestJWT(body: noExpBody)
    let noExp = try decode(jwt: noExpJWT)
    
    #expect(noExp.expired == false)
  }

  @Test
  func testClaimString() throws {
    let body: [String: Any] = ["name": "John Doe"]
    let jwtString = createTestJWT(body: body)
    let jwt = try decode(jwt: jwtString)
    
    let claim = jwt.claim(name: "name")
    #expect(claim.string == "John Doe")
    
    // Non-string claim
    let nonStringClaim = jwt.claim(name: "nonexistent")
    #expect(nonStringClaim.string == nil)
  }

  @Test
  func testClaimBoolean() throws {
    let body: [String: Any] = ["isActive": true, "isDisabled": false]
    let jwtString = createTestJWT(body: body)
    let jwt = try decode(jwt: jwtString)
    
    let trueClaim = jwt.claim(name: "isActive")
    #expect(trueClaim.boolean == true)
    
    let falseClaim = jwt.claim(name: "isDisabled")
    #expect(falseClaim.boolean == false)
    
    // Non-boolean claim
    let nonBoolClaim = jwt.claim(name: "nonexistent")
    #expect(nonBoolClaim.boolean == nil)
  }

  @Test
  func testClaimDouble() throws {
    let body: [String: Any] = ["price": 99.99, "priceString": "99.99"]
    let jwtString = createTestJWT(body: body)
    let jwt = try decode(jwt: jwtString)
    
    let priceClaim = jwt.claim(name: "price")
    #expect(priceClaim.double == 99.99)
    
    // String that can be converted to double
    let priceStringClaim = jwt.claim(name: "priceString")
    #expect(priceStringClaim.double == 99.99)
  }

  @Test
  func testClaimInteger() throws {
    let body: [String: Any] = ["age": 30, "ageString": "30", "ageDouble": 30.0]
    let jwtString = createTestJWT(body: body)
    let jwt = try decode(jwt: jwtString)
    
    let ageClaim = jwt.claim(name: "age")
    #expect(ageClaim.integer == 30)
    
    // String that can be converted to integer
    let ageStringClaim = jwt.claim(name: "ageString")
    #expect(ageStringClaim.integer == 30)
    
    // Double that can be converted to integer
    let ageDoubleClaim = jwt.claim(name: "ageDouble")
    #expect(ageDoubleClaim.integer == 30)
  }

  @Test
  func testClaimDate() throws {
    let timestamp = 1609459200.0
    let body: [String: Any] = ["exp": timestamp]
    let jwtString = createTestJWT(body: body)
    let jwt = try decode(jwt: jwtString)
    
    let expClaim = jwt.claim(name: "exp")
    let date = expClaim.date
    #expect(date != nil)
    #expect(date?.timeIntervalSince1970 == timestamp)
  }

  @Test
  func testClaimArray() throws {
    let body: [String: Any] = [
      "roles": ["admin", "user"],
      "singleRole": "admin"
    ]
    let jwtString = createTestJWT(body: body)
    let jwt = try decode(jwt: jwtString)
    
    let rolesClaim = jwt.claim(name: "roles")
    #expect(rolesClaim.array == ["admin", "user"])
    
    // Single string should be converted to array
    let singleRoleClaim = jwt.claim(name: "singleRole")
    #expect(singleRoleClaim.array == ["admin"])
  }

  @Test
  func testClaimSubscript() throws {
    let body: [String: Any] = ["name": "John"]
    let jwtString = createTestJWT(body: body)
    let jwt = try decode(jwt: jwtString)
    
    #expect(jwt["name"].string == "John")
    #expect(jwt["nonexistent"].string == nil)
  }

  @Test
  func testJWTStringValue() throws {
    let body: [String: Any] = ["sub": "user123"]
    let jwtString = createTestJWT(body: body)
    let jwt = try decode(jwt: jwtString)
    
    #expect(jwt.string == jwtString)
  }

  @Test
  func testJWTHeader() throws {
    let header: [String: Any] = ["alg": "HS256", "typ": "JWT"]
    let body: [String: Any] = ["sub": "user123"]
    let jwtString = createTestJWT(header: header, body: body)
    let jwt = try decode(jwt: jwtString)
    
    #expect(jwt.header["alg"] as? String == "HS256")
    #expect(jwt.header["typ"] as? String == "JWT")
  }

  @Test
  func testJWTSignature() throws {
    let body: [String: Any] = ["sub": "user123"]
    let jwtString = createTestJWT(body: body)
    let jwt = try decode(jwt: jwtString)
    
    #expect(jwt.signature == "signature")
  }
}

