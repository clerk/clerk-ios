@testable import ClerkKit
import Foundation
import Testing

struct JSONMergePatchTests {
  @Test
  func addedKeysAppearVerbatim() {
    let current: JSON = ["a": 1]
    let desired: JSON = ["a": 1, "b": 2]
    #expect(current.mergePatch(against: desired) == ["b": 2])
  }

  @Test
  func keysAbsentFromDesiredBecomeNull() {
    let current: JSON = ["a": 1, "b": 2]
    let desired: JSON = ["a": 1]
    #expect(current.mergePatch(against: desired) == ["b": .null])
  }

  @Test
  func changedPrimitiveValuesAreOverwritten() {
    let current: JSON = ["a": 1]
    let desired: JSON = ["a": 2]
    #expect(current.mergePatch(against: desired) == ["a": 2])
  }

  @Test
  func unchangedValuesAreSkipped() {
    let current: JSON = ["a": 1, "b": 2]
    let desired: JSON = ["a": 1, "b": 2]
    #expect(current.mergePatch(against: desired) == .object([:]))
  }

  @Test
  func nestedObjectsRecurseAndEmitOnlyChangedSubKeys() {
    let current: JSON = ["profile": ["theme": "dark", "font": "sans"]]
    let desired: JSON = ["profile": ["theme": "light", "font": "sans"]]
    #expect(current.mergePatch(against: desired) == ["profile": ["theme": "light"]])
  }

  @Test
  func removedNestedKeyIsNulledSiblingsUntouched() {
    let current: JSON = ["profile": ["theme": "dark", "font": "sans"]]
    let desired: JSON = ["profile": ["font": "sans"]]
    #expect(current.mergePatch(against: desired) == ["profile": ["theme": .null]])
  }

  @Test
  func typeMismatchReturnsDesiredVerbatim() {
    let current: JSON = ["a": 1]
    let desired: JSON = "replaced"
    #expect(current.mergePatch(against: desired) == "replaced")
  }

  @Test
  func nullDesiredIsPassedThroughVerbatim() {
    let current: JSON = ["a": 1]
    #expect(current.mergePatch(against: .null) == .null)
  }

  @Test
  func desiredEmptyObjectClearsEveryExistingKey() {
    let current: JSON = ["a": 1, "b": 2]
    let desired: JSON = .object([:])
    #expect(current.mergePatch(against: desired) == ["a": .null, "b": .null])
  }

  @Test
  func emptyCurrentReturnsDesiredVerbatim() {
    let current: JSON = .object([:])
    let desired: JSON = ["a": 1, "b": ["c": 2]]
    #expect(current.mergePatch(against: desired) == desired)
  }

  @Test
  func arraysAreTreatedAsAtomic() {
    // RFC 7396 explicitly treats arrays as opaque.
    let current: JSON = ["tags": ["a", "b"]]
    let desired: JSON = ["tags": ["a"]]
    #expect(current.mergePatch(against: desired) == ["tags": ["a"]])
  }

  @Test
  func applyingThePatchReproducesDesired() {
    // Use a local RFC 7396 applier (null deletes) as the oracle. JSON.merging(with:)
    // is *not* RFC 7396 — it retains .null values instead of deleting keys.
    let current: JSON = [
      "a": 1,
      "nested": ["x": 1, "y": 2],
      "removed": true,
    ]
    let desired: JSON = [
      "a": 2,
      "nested": ["x": 1, "z": 3],
      "added": "yes",
    ]

    let patch = current.mergePatch(against: desired)
    #expect(applyMergePatch(current, patch) == desired)
    if case let .object(patchObj) = patch {
      #expect(!patchObj.isEmpty, "Patch must not be empty for a real change")
    } else {
      Issue.record("Expected the patch to be a JSON object")
    }
  }

  // MARK: - Helpers

  /// RFC 7396 reference applier: null values delete keys, recursion on objects,
  /// non-object patch values fully replace at that node.
  private func applyMergePatch(_ target: JSON, _ patch: JSON) -> JSON {
    guard case let .object(patchObj) = patch else { return patch }
    var out: [String: JSON] =
      if case let .object(t) = target {
        t
      } else {
        [:]
      }
    for (key, value) in patchObj {
      if case .null = value {
        out.removeValue(forKey: key)
      } else {
        let nested = out[key] ?? .object([:])
        out[key] = applyMergePatch(nested, value)
      }
    }
    return .object(out)
  }
}
