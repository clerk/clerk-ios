//
//  SharedSessionSyncCoordinator+ResponseOrdering.swift
//  Clerk
//

import Foundation

extension SharedSessionSyncCoordinator {
  func responseCanBeAccepted(
    sequence: Int?,
    serverDate: Date?,
    incomingClient: Client?,
    currentClient: Client?
  ) -> Bool {
    responseOrderingGate.accepts(
      sequence: sequence,
      serverDate: serverDate,
      incomingUpdatedAt: incomingClient?.updatedAt,
      currentUpdatedAt: currentClient?.updatedAt
    )
  }

  func checkpointAllowsPublication(_ checkpoint: PublicationCheckpoint) -> Bool {
    switch checkpoint {
    case .none:
      true
    case let .response(baseGeneration, requestDeviceToken):
      responseCanPublish(
        from: baseGeneration,
        requestDeviceToken: requestDeviceToken
      )
    }
  }

  func responseCanPublish(
    from baseGeneration: UInt64,
    requestDeviceToken: String?
  ) -> Bool {
    guard requestDeviceToken == currentDeviceToken else { return false }
    if baseGeneration == currentMaximumGeneration {
      return true
    }
    guard let networkResponseLineage else { return false }
    return baseGeneration >= networkResponseLineage.rootGeneration
      && baseGeneration <= networkResponseLineage.frontierGeneration
      && networkResponseLineage.frontierGeneration == currentMaximumGeneration
      && networkResponseLineage.deviceToken == currentDeviceToken
  }

  func networkResponseCandidate(
    for checkpoint: PublicationCheckpoint,
    eventID: UUID
  ) -> (eventID: UUID, rootGeneration: UInt64)? {
    guard case .response(let baseGeneration, _) = checkpoint else { return nil }
    return (eventID, baseGeneration)
  }

  func updateNetworkResponseLineage(
    winner: SharedSessionIdentityEvent,
    previousAcceptedEventID: UUID?,
    candidate: (eventID: UUID, rootGeneration: UInt64)?
  ) {
    if let candidate, winner.id == candidate.eventID {
      let rootGeneration = if let networkResponseLineage,
                              networkResponseLineage.deviceToken == currentDeviceToken,
                              networkResponseLineage.frontierGeneration < winner.generation,
                              candidate.rootGeneration >= networkResponseLineage.rootGeneration,
                              candidate.rootGeneration <= networkResponseLineage.frontierGeneration
      {
        networkResponseLineage.rootGeneration
      } else {
        candidate.rootGeneration
      }
      networkResponseLineage = NetworkResponseLineage(
        rootGeneration: rootGeneration,
        frontierGeneration: winner.generation,
        deviceToken: currentDeviceToken
      )
    } else if candidate != nil || winner.id != previousAcceptedEventID {
      networkResponseLineage = nil
    }
  }
}
