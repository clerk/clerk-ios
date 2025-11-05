//
//  InstanceEnvironmentTypeTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct InstanceEnvironmentTypeTests {
  @Test
  func enumCases() {
    #expect(InstanceEnvironmentType.production.rawValue == "production")
    #expect(InstanceEnvironmentType.development.rawValue == "development")
    #expect(InstanceEnvironmentType.unknown.rawValue == "unknown")
  }

  @Test
  func testEncoding() throws {
    let encoder = JSONEncoder()

    let productionData = try encoder.encode(InstanceEnvironmentType.production)
    let productionString = String(data: productionData, encoding: .utf8)
    #expect(productionString == "\"production\"")

    let developmentData = try encoder.encode(InstanceEnvironmentType.development)
    let developmentString = String(data: developmentData, encoding: .utf8)
    #expect(developmentString == "\"development\"")

    let unknownData = try encoder.encode(InstanceEnvironmentType.unknown)
    let unknownString = String(data: unknownData, encoding: .utf8)
    #expect(unknownString == "\"unknown\"")
  }

  @Test
  func decoding() throws {
    let decoder = JSONDecoder()

    let productionData = "\"production\"".data(using: .utf8)!
    let production = try decoder.decode(InstanceEnvironmentType.self, from: productionData)
    #expect(production == .production)

    let developmentData = "\"development\"".data(using: .utf8)!
    let development = try decoder.decode(InstanceEnvironmentType.self, from: developmentData)
    #expect(development == .development)

    let unknownData = "\"unknown\"".data(using: .utf8)!
    let unknown = try decoder.decode(InstanceEnvironmentType.self, from: unknownData)
    #expect(unknown == .unknown)
  }

  @Test
  func decodingInvalidValue() throws {
    let decoder = JSONDecoder()

    // Invalid value should decode to unknown
    let invalidData = "\"invalid\"".data(using: .utf8)!
    let result = try decoder.decode(InstanceEnvironmentType.self, from: invalidData)
    #expect(result == .unknown)
  }

  @Test
  func rawValueAccess() {
    #expect(InstanceEnvironmentType.production.rawValue == "production")
    #expect(InstanceEnvironmentType.development.rawValue == "development")
    #expect(InstanceEnvironmentType.unknown.rawValue == "unknown")
  }

  @Test
  func equatable() {
    #expect(InstanceEnvironmentType.production == .production)
    #expect(InstanceEnvironmentType.development == .development)
    #expect(InstanceEnvironmentType.unknown == .unknown)
    #expect(InstanceEnvironmentType.production != .development)
  }
}
