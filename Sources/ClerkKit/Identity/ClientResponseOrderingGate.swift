//
//  ClientResponseOrderingGate.swift
//  Clerk
//

import Foundation

struct ClientResponseOrderingGate {
  private(set) var lastAcceptedSequence: Int?
  var lastAcceptedServerDate: Date?

  init(
    lastAcceptedSequence: Int? = nil,
    lastAcceptedServerDate: Date? = nil
  ) {
    self.lastAcceptedSequence = lastAcceptedSequence
    self.lastAcceptedServerDate = lastAcceptedServerDate
  }

  func accepts(
    sequence: Int?,
    serverDate: Date?,
    incomingUpdatedAt: Date?,
    currentUpdatedAt: Date?
  ) -> Bool {
    guard let sequence,
          let lastAcceptedSequence,
          sequence <= lastAcceptedSequence
    else {
      return true
    }
    return responseIsNewer(
      serverDate: serverDate,
      incomingUpdatedAt: incomingUpdatedAt,
      currentUpdatedAt: currentUpdatedAt
    )
  }

  mutating func record(sequence: Int?, serverDate: Date? = nil) {
    guard let sequence else { return }
    lastAcceptedSequence = max(lastAcceptedSequence ?? sequence, sequence)
    if let serverDate {
      lastAcceptedServerDate = serverDate
    }
  }

  mutating func reset() {
    lastAcceptedSequence = nil
    lastAcceptedServerDate = nil
  }

  mutating func resetSequence() {
    lastAcceptedSequence = nil
  }

  private func responseIsNewer(
    serverDate: Date?,
    incomingUpdatedAt: Date?,
    currentUpdatedAt: Date?
  ) -> Bool {
    guard let serverDate, let lastAcceptedServerDate else { return false }
    if serverDate > lastAcceptedServerDate { return true }
    guard serverDate == lastAcceptedServerDate,
          let incomingUpdatedAt,
          let currentUpdatedAt
    else {
      return false
    }
    return incomingUpdatedAt > currentUpdatedAt
  }
}
