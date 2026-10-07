//
//  KeychainWriteQueueTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct KeychainWriteQueueTests {
  @Test
  func writesRunOffTheMainThread() async {
    let keychain = ThreadRecordingKeychain()
    let writes = KeychainWriteQueue()

    writes.enqueue(.cachedClient) { try? keychain.set(Data("client".utf8), forKey: "client") }
    await writes.waitForPendingWrites()

    #expect(keychain.mainThreadWrites.isEmpty)
    #expect(keychain.backgroundWrites == ["client"])
  }

  @Test
  func onlyTheLatestPendingWriteForAKeyRuns() async {
    let keychain = StalledWriteKeychain()
    let writes = KeychainWriteQueue()

    enqueue("running", into: keychain, on: writes)
    await keychain.waitUntilWriteStarts()
    enqueue("superseded", into: keychain, on: writes)
    enqueue("latest", into: keychain, on: writes)
    keychain.release()
    await writes.waitForPendingWrites()

    #expect(keychain.writtenValues == [Data("running".utf8), Data("latest".utf8)])
  }

  @Test
  func writesForDifferentKeysAreNotCoalesced() async throws {
    let keychain = InMemoryKeychain()
    let writes = KeychainWriteQueue()

    writes.enqueue(.cachedClient) { try? keychain.set(Data("client".utf8), forKey: "client") }
    writes.enqueue(.cachedEnvironment) { try? keychain.set(Data("environment".utf8), forKey: "environment") }
    await writes.waitForPendingWrites()

    #expect(try keychain.data(forKey: "client") == Data("client".utf8))
    #expect(try keychain.data(forKey: "environment") == Data("environment".utf8))
  }

  @Test
  func aLaterDeleteForTheSameKeyRunsAfterARunningWrite() async throws {
    let keychain = StalledWriteKeychain()
    let writes = KeychainWriteQueue()

    enqueue("running", into: keychain, on: writes)
    await keychain.waitUntilWriteStarts()
    writes.enqueue(.cachedClient) { try? keychain.deleteItem(forKey: "client") }
    keychain.release()
    await writes.waitForPendingWrites()

    #expect(try keychain.data(forKey: "client") == nil)
  }

  @Test
  func discardingWaitsForTheRunningWriteAndDropsPendingOnes() async {
    let keychain = StalledWriteKeychain()
    let writes = KeychainWriteQueue()

    enqueue("running", into: keychain, on: writes)
    await keychain.waitUntilWriteStarts()
    enqueue("pending", into: keychain, on: writes)
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { keychain.release() }
    writes.discardPendingWrites()

    #expect(keychain.writtenValues == [Data("running".utf8)])
    await writes.waitForPendingWrites()
    #expect(keychain.writtenValues == [Data("running".utf8)])
  }

  @Test
  func pausedWritesWaitUntilResumed() async throws {
    let keychain = InMemoryKeychain()
    let writes = KeychainWriteQueue()

    writes.pauseWrites()
    writes.enqueue(.cachedClient) { try? keychain.set(Data("client".utf8), forKey: "client") }
    await writes.waitForPendingWrites()
    #expect(try keychain.data(forKey: "client") == nil)

    writes.resumeWrites()
    await writes.waitForPendingWrites()
    #expect(try keychain.data(forKey: "client") == Data("client".utf8))
  }

  @Test
  func aWriteQueuedWhilePausedDoesNotHoldUpDiscarding() async {
    let keychain = StalledWriteKeychain()
    let writes = KeychainWriteQueue()

    writes.pauseWrites()
    await writes.waitForPendingWrites()
    enqueue("queued while paused", into: keychain, on: writes)
    DispatchQueue.global().asyncAfter(deadline: .now() + 2) { keychain.release() }
    writes.discardPendingWrites()
    writes.resumeWrites()
    await writes.waitForPendingWrites()

    #expect(keychain.writtenValues.isEmpty)
  }

  @Test
  func aWriteScheduledBeforePausingWaitsForResume() async {
    let keychain = StalledWriteKeychain()
    let writes = KeychainWriteQueue()

    enqueue("running", into: keychain, on: writes)
    await keychain.waitUntilWriteStarts()
    enqueue("scheduled", into: keychain, on: writes)
    writes.pauseWrites()
    keychain.release()
    await writes.waitForPendingWrites()
    #expect(keychain.writtenValues == [Data("running".utf8)])

    writes.resumeWrites()
    await writes.waitForPendingWrites()
    #expect(keychain.writtenValues == [Data("running".utf8), Data("scheduled".utf8)])
  }

  @Test
  func writingNowDropsAPendingWriteForTheSameKey() async {
    let keychain = StalledWriteKeychain()
    let writes = KeychainWriteQueue()

    enqueue("running", into: keychain, on: writes)
    await keychain.waitUntilWriteStarts()
    enqueue("pending", into: keychain, on: writes)
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { keychain.release() }
    writes.writeNow(.cachedClient) { try? keychain.set(Data("now".utf8), forKey: "client") }
    await writes.waitForPendingWrites()

    #expect(keychain.writtenValues == [Data("running".utf8), Data("now".utf8)])
  }

  private func enqueue(_ value: String, into keychain: StalledWriteKeychain, on writes: KeychainWriteQueue) {
    writes.enqueue(.cachedClient) { try? keychain.set(Data(value.utf8), forKey: "client") }
  }
}
