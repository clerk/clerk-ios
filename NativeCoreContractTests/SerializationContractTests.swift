import ClerkKit
import Foundation
import Testing

@MainActor
struct SerializationContractTests {
  @Test func nestedMetadataKeepsNullsNumbersAndBooleansAcrossCodable() throws {
    let source: JSONValue = .object([
      "string": .string("hello"), "number": .number(42.5), "bool": .bool(true),
      "null": .null, "array": .array([.string("a"), .number(1), .bool(false)]),
      "object": .object(["removed": .null, "retained": .string("yes")]),
    ])
    let encoded = try JSONEncoder().encode(source)
    #expect(try JSONDecoder().decode(JSONValue.self, from: encoded) == source)
    let decoded = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"bool":true,"number":1,"null":null}"#.utf8)).object()
    #expect(decoded["bool"] == .bool(true))
    #expect(decoded["number"] == .number(1))
    #expect(decoded["null"] == .null)
    let boolean = try #require(decoded["bool"])
    let number = try #require(decoded["number"])
    #expect(throws: CoreError.self) { try boolean.number() }
    #expect(throws: CoreError.self) { try number.bool() }
    #expect(throws: (any Error).self) { try JSONDecoder().decode(JSONValue.self, from: Data("{invalid}".utf8)) }
  }

  @Test func generatedUserUpdateDistinguishesOmissionClearingAndValues() throws {
    let input = UpdateUserParams(firstName: .null, lastName: .value("Doe"), unsafeMetadata: ["removed": .null, "kept": .string("yes")])
    let body = try input.encode().object()
    #expect(body["username"] == nil)
    #expect(body["firstName"] == .null)
    #expect(body["lastName"] == .string("Doe"))
    #expect(body["unsafeMetadata"] == .object(["removed": .null, "kept": .string("yes")]))
    #expect(body["first_name"] == nil)
  }

  @Test(arguments: ["2021-01-01T00:00:00Z", "2021-01-01T00:00:00.000Z"])
  func projectedDatesUseISO8601(date: String) throws {
    #expect(try JSONValue.string(date).date() == Date(timeIntervalSince1970: 1_609_459_200))
  }
}
