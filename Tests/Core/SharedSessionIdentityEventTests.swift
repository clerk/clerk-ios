@testable import ClerkKit
import Foundation
import Testing

struct SharedSessionIdentityEventTests {
  @Test
  func namespaceIncludesNormalizedPublishableKey() {
    let testNamespace = SharedSessionNamespace(
      frontendApiUrl: " https://same-instance.example/ ",
      publishableKey: " pk_test_same-instance\n"
    )
    let sameNamespace = SharedSessionNamespace(
      frontendApiUrl: "https://same-instance.example",
      publishableKey: "pk_test_same-instance"
    )
    let liveNamespace = SharedSessionNamespace(
      frontendApiUrl: "https://same-instance.example",
      publishableKey: "pk_live_same-instance"
    )

    #expect(testNamespace == sameNamespace)
    #expect(testNamespace != liveNamespace)
  }

  @Test
  func reducerReturnsSameWinnerForEveryPermutation() {
    let events = [
      makeEvent(id: "00000000-0000-0000-0000-000000000001", owner: "app.a", generation: 1),
      makeEvent(id: "00000000-0000-0000-0000-000000000002", owner: "app.b", generation: 2),
      makeEvent(id: "00000000-0000-0000-0000-000000000003", owner: "app.c", generation: 3),
      makeEvent(id: "00000000-0000-0000-0000-000000000004", owner: "app.d", generation: 4),
    ]

    for permutation in permutations(of: events) {
      let reduction = SharedSessionIdentityReducer.reduce(events: permutation)
      #expect(reduction.winner?.id == events[3].id)
      #expect(reduction.maximumGeneration == 4)
    }
  }

  @Test
  func reducerDeduplicatesReplicatedCopies() {
    let older = makeEvent(owner: "app.a", generation: 1)
    let newer = makeEvent(owner: "app.b", generation: 2)

    let reduction = SharedSessionIdentityReducer.reduce(events: [newer, older, newer, newer])

    #expect(reduction.winner == newer)
    #expect(reduction.maximumGeneration == 2)
  }

  @Test
  func generationTakesPriorityOverDifferingServerDates() {
    let laterGeneration = makeEvent(
      owner: "app.a",
      generation: 10,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let laterServerDate = makeEvent(
      owner: "app.b",
      generation: 1,
      serverDate: Date(timeIntervalSince1970: 200)
    )

    let reduction = SharedSessionIdentityReducer.reduce(events: [laterGeneration, laterServerDate])

    #expect(reduction.winner == laterGeneration)
    #expect(reduction.maximumGeneration == 10)
  }

  @Test
  func serverDatePresenceBreaksEqualGenerationTie() {
    let dated = makeEvent(
      owner: "app.z",
      generation: 1,
      serverDate: Date(timeIntervalSince1970: 200)
    )
    let undated = makeEvent(owner: "app.a", generation: 1)

    #expect(SharedSessionIdentityReducer.reduce(events: [dated, undated]).winner == dated)
  }

  @Test
  func mixedDateGenerationsHaveOneWinnerForEveryPermutation() {
    let events = [
      makeEvent(owner: "app.a", generation: 1, serverDate: Date(timeIntervalSince1970: 300)),
      makeEvent(owner: "app.b", generation: 2),
      makeEvent(owner: "app.c", generation: 3, serverDate: Date(timeIntervalSince1970: 200)),
    ]

    for permutation in permutations(of: events) {
      #expect(SharedSessionIdentityReducer.reduce(events: permutation).winner == events[2])
    }
  }

  @Test
  func mixedDatePresenceAtEqualGenerationHasOneWinnerForEveryPermutation() {
    let events = [
      makeEvent(owner: "app.a", generation: 2, serverDate: Date(timeIntervalSince1970: 300)),
      makeEvent(owner: "app.b", generation: 2),
      makeEvent(owner: "app.c", generation: 2, serverDate: Date(timeIntervalSince1970: 200)),
    ]

    for permutation in permutations(of: events) {
      #expect(SharedSessionIdentityReducer.reduce(events: permutation).winner == events[0])
    }
  }

  @Test
  func ownerAndEventIDBreakTiesDeterministically() {
    let ownerA = makeEvent(
      id: "00000000-0000-0000-0000-000000000099",
      owner: "app.a",
      generation: 2
    )
    let ownerBFirst = makeEvent(
      id: "00000000-0000-0000-0000-000000000001",
      owner: "app.b",
      generation: 2
    )
    let ownerBLast = makeEvent(
      id: "00000000-0000-0000-0000-000000000002",
      owner: "app.b",
      generation: 2
    )

    #expect(
      SharedSessionIdentityReducer.reduce(events: [ownerBFirst, ownerA, ownerBLast]).winner == ownerBLast
    )
  }

  @Test
  func reducerDoesNotUseClientUpdatedAt() {
    var oldClient = Client.mock
    oldClient.updatedAt = Date(timeIntervalSince1970: 100)
    var newClient = Client.mock
    newClient.updatedAt = Date(timeIntervalSince1970: 10000)

    let higherGeneration = makeEvent(owner: "app.a", generation: 2, client: oldClient)
    let newerClientTimestamp = makeEvent(owner: "app.z", generation: 1, client: newClient)

    #expect(
      SharedSessionIdentityReducer.reduce(events: [higherGeneration, newerClientTimestamp]).winner == higherGeneration
    )
  }

  @Test
  func signOutDoesNotAutomaticallyBeatSignIn() {
    let clear = makeEvent(owner: "app.a", generation: 3, state: .cleared, token: nil, client: nil)
    let present = makeEvent(owner: "app.z", generation: 3)

    #expect(SharedSessionIdentityReducer.reduce(events: [clear, present]).winner == present)
  }

  @Test
  func conflictingCopiesWithSameIDAreExcludedDeterministically() {
    let id = "00000000-0000-0000-0000-000000000001"
    let first = makeEvent(id: id, owner: "app.a", generation: 9)
    let conflicting = makeEvent(id: id, owner: "app.b", generation: 10)
    let valid = makeEvent(owner: "app.c", generation: 2)

    let reduction = SharedSessionIdentityReducer.reduce(events: [conflicting, valid, first])

    #expect(reduction.winner == valid)
    #expect(reduction.maximumGeneration == 10)
    #expect(reduction.conflictingEventIDs == [first.id])
  }

  @Test
  func eventValidationRequiresCoherentAtomicIdentity() {
    #expect(throws: SharedSessionIdentityEventError.invalidGeneration) {
      try makeEvent(owner: "app.a", generation: 0).validated()
    }
    #expect(throws: ClerkIdentitySnapshotError.invalidPresentState) {
      try makeEvent(owner: "app.a", generation: 1, token: nil).validated()
    }
    #expect(throws: ClerkIdentitySnapshotError.invalidClearedState) {
      try makeEvent(owner: "app.a", generation: 1, state: .cleared).validated()
    }
  }

  @Test
  func generationIncrementFailsClosedOnOverflow() {
    #expect(throws: SharedSessionIdentityEventError.generationOverflow) {
      try SharedSessionIdentityEvent.nextGeneration(after: .max)
    }
  }

  private func makeEvent(
    id: String = UUID().uuidString,
    owner: String,
    generation: UInt64,
    state: SharedSessionIdentityEvent.State = .present,
    token: String? = "token",
    client: Client? = .mock,
    serverDate: Date? = nil
  ) -> SharedSessionIdentityEvent {
    SharedSessionIdentityEvent(
      id: UUID(uuidString: id)!,
      originOwnerIdentifier: owner,
      generation: generation,
      state: state,
      deviceToken: token,
      client: client,
      serverDate: serverDate
    )
  }

  private func permutations<T>(of values: [T]) -> [[T]] {
    guard let first = values.first else { return [[]] }
    return permutations(of: Array(values.dropFirst())).flatMap { permutation in
      (0 ... permutation.count).map { index in
        var result = permutation
        result.insert(first, at: index)
        return result
      }
    }
  }
}
