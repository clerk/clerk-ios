//
//  JSON+MergePatch.swift
//  Clerk
//

extension JSON {
  func mergePatch(against desired: JSON) -> JSON {
    guard case let .object(desiredObject) = desired else {
      return desired
    }

    guard case let .object(currentObject) = self else {
      return desired
    }

    return .object(Self.mergePatch(from: currentObject, to: desiredObject))
  }

  private static func mergePatch(
    from current: [String: JSON],
    to desired: [String: JSON]
  ) -> [String: JSON] {
    var patch: [String: JSON] = [:]

    for (key, desiredValue) in desired {
      guard let currentValue = current[key] else {
        patch[key] = desiredValue
        continue
      }

      if currentValue == desiredValue {
        continue
      }

      if case let .object(currentObject) = currentValue,
         case let .object(desiredObject) = desiredValue
      {
        patch[key] = .object(mergePatch(from: currentObject, to: desiredObject))
      } else {
        patch[key] = desiredValue
      }
    }

    for key in current.keys where desired[key] == nil {
      patch[key] = .null
    }

    return patch
  }
}
