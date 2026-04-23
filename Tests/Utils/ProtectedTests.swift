@testable import ClerkKit
import Testing

@Suite(.tags(.unit))
struct ProtectedTests {
  @Test
  func protectedRead() {
    let protected = Protected("test value")

    let result = protected.read { value in
      value
    }

    #expect(result == "test value")
  }

  @Test
  func protectedReadWithTransformation() {
    let protected = Protected(42)

    let result = protected.read { value in
      value * 2
    }

    #expect(result == 84)
  }

  @Test
  func protectedWriteWithValue() {
    let protected = Protected("initial")

    protected.write("updated")

    let result = protected.read { $0 }
    #expect(result == "updated")
  }

  @Test
  func protectedWriteWithClosure() {
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
  func protectedWriteWithClosureReturningDifferentType() {
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
  func protectedDynamicMemberLookupWritableKeyPath() {
    struct TestStruct {
      var name: String
      var age: Int
    }

    let protected = Protected(TestStruct(name: "John", age: 30))

    #expect(protected.name == "John")
    #expect(protected.age == 30)

    protected.name = "Jane"
    protected.age = 25

    #expect(protected.name == "Jane")
    #expect(protected.age == 25)
  }

  @Test
  func protectedDynamicMemberLookupReadOnlyKeyPath() {
    struct TestStruct {
      let name: String
      var age: Int
    }

    let protected = Protected(TestStruct(name: "John", age: 30))

    #expect(protected.name == "John")
    #expect(protected.age == 30)

    protected.age = 25
    #expect(protected.age == 25)
  }

  @Test
  func protectedThreadSafety() async {
    let protected = Protected(0)

    await withTaskGroup(of: Void.self) { group in
      for i in 1 ... 100 {
        group.addTask {
          protected.write { value in
            value += i
          }
        }
      }
    }

    let finalValue = protected.read { $0 }
    #expect(finalValue == 5050)
  }

  @Test
  func protectedConcurrentReadWrite() async {
    let protected = Protected(0)

    await withTaskGroup(of: Void.self) { group in
      for i in 1 ... 50 {
        group.addTask {
          protected.write { value in
            value += i
          }
        }
      }

      for _ in 1 ... 50 {
        group.addTask {
          _ = protected.read { $0 }
        }
      }
    }

    let finalValue = protected.read { $0 }
    #expect(finalValue == (1 ... 50).reduce(0, +))
  }
}
