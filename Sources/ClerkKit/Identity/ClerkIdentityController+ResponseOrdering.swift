//
//  ClerkIdentityController+ResponseOrdering.swift
//  Clerk
//

import Foundation

extension ClerkIdentityController {
  func responseCanBeAccepted(
    _ incoming: Client?,
    responseSequence: Int?,
    serverDate: Date?,
    clientResponseGeneration: ClientResponseGeneration?,
    clerk: Clerk
  ) -> Bool {
    if let clientResponseGeneration,
       clientResponseGeneration != self.clientResponseGeneration
    {
      ClerkLogger.debug(
        "Ignoring client response from stale device token generation. Current generation: \(self.clientResponseGeneration), incoming generation: \(clientResponseGeneration)"
      )
      return false
    }

    if let responseSequence {
      if let lastAppliedResponseSequence,
         responseSequence <= lastAppliedResponseSequence,
         !responseIsNewerThanCurrent(incoming, serverDate: serverDate, clerk: clerk)
      {
        ClerkLogger.debug(
          "Ignoring stale client response. Current sequence: \(lastAppliedResponseSequence), incoming sequence: \(responseSequence)"
        )
        return false
      }
    }
    return true
  }

  func recordAcceptedResponse(sequence: Int?) {
    guard let sequence else { return }
    lastAppliedResponseSequence = max(
      lastAppliedResponseSequence ?? sequence,
      sequence
    )
  }

  private func responseIsNewerThanCurrent(
    _ incoming: Client?,
    serverDate: Date?,
    clerk: Clerk
  ) -> Bool {
    guard let serverDate, let lastServerDate else { return false }
    if serverDate > lastServerDate { return true }
    guard serverDate == lastServerDate,
          let incoming,
          let currentClient = clerk.client
    else {
      return false
    }
    return incoming.updatedAt > currentClient.updatedAt
  }
}
