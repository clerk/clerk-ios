//
//  ProtectedTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct ProtectedTests {
  @Test
  func testRead() {
    let protected = Protected("test value")

    let result = protected.read { value in
      value
    }

    #expect(result == "test value")
  }

  @Test
  func readWithTransformation() {
    let protected = Protected(42)

    let result = protected.read { value in
      value * 2
    }

    #expect(result == 84)
  }

  @Test
  func writeWithValue() {
    let protected = Protected("initial")

    protected.write("updated")

    let result = protected.read { $0 }
    #expect(result == "updated")
  }

  @Test
  func writeWithClosure() {
    let protected = Protected(10)

    let result = protected.write { value in
      value += 5
      return value
    }

    #expect(result == 15)

    let finalValue = protected.read { $0 }
    #expect(finalValue == 15)
  }

  @Test
  func writeWithClosureReturningDifferentType() {
    let protected = Protected(10)

    let result = protected.write { value in
      value += 5
      return "result: \(value)"
    }

    #expect(result == "result: 15")

    let finalValue = protected.read { $0 }
    #expect(finalValue == 15)
  }

  @Test
  func dynamicMemberLookupWritableKeyPath() {
    struct TestStruct {
      var name: String
      var age: Int
    }

    let protected = Protected(TestStruct(name: "John", age: 30))

    // Read using dynamic member lookup
    #expect(protected.name == "John")
    #expect(protected.age == 30)

    // Write using dynamic member lookup
    protected.name = "Jane"
    protected.age = 25

    #expect(protected.name == "Jane")
    #expect(protected.age == 25)
  }

  @Test
  func dynamicMemberLookupReadOnlyKeyPath() {
    struct TestStruct {
      let name: String
      var age: Int
    }

    let protected = Protected(TestStruct(name: "John", age: 30))

    // Read using dynamic member lookup
    #expect(protected.name == "John")
    #expect(protected.age == 30)

    // Can modify mutable properties
    protected.age = 25
    #expect(protected.age == 25)
  }

  @Test
  func threadSafety() async {
    let protected = Protected(0)

    // Concurrent writes
    await withTaskGroup(of: Void.self) { group in
      for i in 1 ... 100 {
        group.addTask {
          protected.write { value in
            value += i
          }
        }
      }
    }

    // Verify final value (should be sum of 1 to 100 = 5050)
    let finalValue = protected.read { $0 }
    #expect(finalValue == 5050)
  }

  @Test
  func concurrentReadWrite() async {
    let protected = Protected(0)

    await withTaskGroup(of: Void.self) { group in
      // Multiple writers
      for i in 1 ... 50 {
        group.addTask {
          protected.write { value in
            value += i
          }
        }
      }

      // Multiple readers (should not cause crashes)
      for _ in 1 ... 50 {
        group.addTask {
          _ = protected.read { $0 }
        }
      }
    }

    // Verify final value
    let finalValue = protected.read { $0 }
    #expect(finalValue == (1 ... 50).reduce(0, +))
  }
}
