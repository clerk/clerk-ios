@testable import ClerkKit
import Foundation
import Testing

@Suite(.tags(.unit))
struct URLEncodedFormEncoderEncodingTests {
  @Test
  func encodeSimpleStruct() throws {
    struct TestStruct: Encodable {
      let name: String
      let age: Int
    }

    let encoder = URLEncodedFormEncoder()
    let value = TestStruct(name: "John", age: 30)
    let result: String = try encoder.encode(value)

    #expect(result.contains("name=John"))
    #expect(result.contains("age=30"))
  }

  @Test
  func encodeWithArrays() throws {
    struct TestStruct: Encodable {
      let items: [String]
    }

    let encoder = URLEncodedFormEncoder()
    let value = TestStruct(items: ["a", "b", "c"])
    let result: String = try encoder.encode(value)

    #expect(result.contains("items%5B%5D=a") || result.contains("items[]=a"))
    #expect(result.contains("items%5B%5D=b") || result.contains("items[]=b"))
    #expect(result.contains("items%5B%5D=c") || result.contains("items[]=c"))
  }

  @Test
  func encodeWithNestedObjects() throws {
    struct Nested: Encodable {
      let value: String
    }
    struct TestStruct: Encodable {
      let parent: Nested
    }

    let encoder = URLEncodedFormEncoder()
    let value = TestStruct(parent: Nested(value: "test"))
    let result: String = try encoder.encode(value)

    #expect(result.contains("parent%5Bvalue%5D=test") || result.contains("parent[value]=test"))
  }

  @Test
  func encodeWithBoolNumeric() throws {
    struct TestStruct: Encodable {
      let flag: Bool
    }

    let encoder = URLEncodedFormEncoder(boolEncoding: .numeric)
    let value = TestStruct(flag: true)
    let result: String = try encoder.encode(value)

    #expect(result.contains("flag=1"))

    let valueFalse = TestStruct(flag: false)
    let resultFalse: String = try encoder.encode(valueFalse)
    #expect(resultFalse.contains("flag=0"))
  }

  @Test
  func encodeWithBoolLiteral() throws {
    struct TestStruct: Encodable {
      let flag: Bool
    }

    let encoder = URLEncodedFormEncoder(boolEncoding: .literal)
    let value = TestStruct(flag: true)
    let result: String = try encoder.encode(value)

    #expect(result.contains("flag=true"))
  }

  @Test
  func encodeWithOptionalNilDropKey() throws {
    struct TestStruct: Encodable {
      let name: String?
    }

    let encoder = URLEncodedFormEncoder(nilEncoding: .dropKey)
    let value = TestStruct(name: nil)
    let result: String = try encoder.encode(value)

    #expect(!result.contains("name"))
  }

  @Test
  func encodeWithOptionalNilDropValue() throws {
    struct TestStruct: Encodable {
      let name: String?
    }

    let encoder = URLEncodedFormEncoder(nilEncoding: .dropValue)
    let value = TestStruct(name: nil)
    let result: String = try encoder.encode(value)

    #expect(result.contains("name="))
  }

  @Test
  func encodeWithDateSeconds() throws {
    struct TestStruct: Encodable {
      let date: Date
    }

    let encoder = URLEncodedFormEncoder(dateEncoding: .secondsSince1970)
    let date = Date(timeIntervalSince1970: 1_609_459_200)
    let value = TestStruct(date: date)
    let result: String = try encoder.encode(value)

    #expect(result.contains("date=1609459200.0"))
  }

  @Test
  func encodeWithKeyEncodingSnakeCase() throws {
    struct TestStruct: Encodable {
      let firstName: String
      let lastName: String
    }

    let encoder = URLEncodedFormEncoder(keyEncoding: .convertToSnakeCase)
    let value = TestStruct(firstName: "John", lastName: "Doe")
    let result: String = try encoder.encode(value)

    #expect(result.contains("first_name=John"))
    #expect(result.contains("last_name=Doe"))
  }

  @Test
  func encodeErrorInvalidRootObject() throws {
    let encoder = URLEncodedFormEncoder()

    do {
      let _: String = try encoder.encode("just a string")
      Issue.record("Expected invalidRootObject error")
    } catch let error as URLEncodedFormEncoder.Error {
      if case .invalidRootObject = error {
      } else {
        Issue.record("Wrong error type")
      }
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func alphabetizeKeyValuePairs() throws {
    struct TestStruct: Encodable {
      let z: String
      let a: String
      let m: String
    }

    let encoder = URLEncodedFormEncoder(alphabetizeKeyValuePairs: true)
    let value = TestStruct(z: "z", a: "a", m: "m")
    let result: String = try encoder.encode(value)

    let parts = result.split(separator: "&").map(String.init)
    #expect(parts == ["a=a", "m=m", "z=z"])
  }

  @Test
  func encodeAsData() throws {
    struct TestStruct: Encodable {
      let name: String
      let age: Int
    }

    let encoder = URLEncodedFormEncoder()
    let value = TestStruct(name: "John", age: 30)
    let result = try encoder.encode(value) as Data

    #expect(result.count > 0)
    let string = String(data: result, encoding: .utf8)
    #expect(string?.contains("name=John") == true)
  }
}
