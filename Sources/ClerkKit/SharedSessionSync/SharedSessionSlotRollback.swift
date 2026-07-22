//
//  SharedSessionSlotRollback.swift
//  Clerk
//

extension SharedSessionSlotStoring {
  @discardableResult
  func restoreOwnSlot(
    _ previousSlot: SharedSessionOwnerSlot?,
    ifCurrentMatchesPublication expectedSlot: SharedSessionOwnerSlot
  ) throws -> Bool {
    guard try loadOwnSlot()?.matchesPublication(expectedSlot) == true else {
      return false
    }

    if let previousSlot {
      try saveOwnSlot(previousSlot)
    } else {
      try deleteOwnSlot()
    }
    return true
  }
}

extension SharedSessionOwnerSlot {
  func matchesPublication(_ other: SharedSessionOwnerSlot) -> Bool {
    schemaVersion == other.schemaVersion
      && instanceFingerprint == other.instanceFingerprint
      && slotOwnerIdentifier == other.slotOwnerIdentifier
      && event.id == other.event.id
  }
}
