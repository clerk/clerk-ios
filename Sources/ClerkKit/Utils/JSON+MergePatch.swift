//
//  JSON+MergePatch.swift
//  Clerk
//

extension JSON {
  /// Computes a JSON Merge Patch (RFC 7396) that, when applied to `self`,
  /// produces `desired`.
  ///
  /// Keys present in `self` but absent from `desired` become ``JSON/null``
  /// in the patch — RFC 7396 null-delete semantics.
  ///
  /// Used to express *replace* semantics through a merge endpoint: the SDK
  /// holds the current resource state locally, the caller passes the
  /// desired state, and we send the diff that makes the server side end up
  /// at the desired state.
  ///
  /// Behaviour:
  /// - both plain objects: recurse; emit only keys whose value changes
  /// - `desired == .null`: returned verbatim (caller decides what null means)
  /// - any other type mismatch: `desired` is returned (full replace at that node)
  /// - arrays are treated as atomic per RFC 7396
  func mergePatch(against desired: JSON) -> JSON {
    if case .null = desired { return .null }
    guard case let .object(curObj) = self,
          case let .object(desObj) = desired
    else {
      return desired
    }

    var patch: [String: JSON] = [:]

    for (key, des) in desObj {
      guard let cur = curObj[key] else {
        patch[key] = des
        continue
      }
      if case .object = cur, case .object = des {
        let sub = cur.mergePatch(against: des)
        if case let .object(subObj) = sub, subObj.isEmpty { continue }
        patch[key] = sub
      } else if cur != des {
        patch[key] = des
      }
    }

    for key in curObj.keys where desObj[key] == nil {
      patch[key] = .null
    }

    return .object(patch)
  }
}
