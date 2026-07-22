//
//  SharedSessionSlotIO.swift
//  Clerk
//

/// Serializes Security-backed owner-slot operations outside the main actor.
actor SharedSessionSlotIO {
  private let store: any SharedSessionSlotStoring

  init(store: any SharedSessionSlotStoring) {
    self.store = store
  }

  func loadOwnSlot() throws -> SharedSessionOwnerSlot? {
    try store.loadOwnSlot()
  }

  func loadAllSlots() throws -> [SharedSessionOwnerSlot] {
    try store.loadAllSlots()
  }

  func saveOwnSlot(_ slot: SharedSessionOwnerSlot) throws {
    try store.saveOwnSlot(slot)
  }

  func deleteOwnSlot() throws {
    try store.deleteOwnSlot()
  }
}
