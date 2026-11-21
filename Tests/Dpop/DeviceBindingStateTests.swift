@testable import ClerkKit
import Foundation
import Testing

struct DeviceBindingStateTests {
  @Test
  func aSharedTokenIsNeverSigned() async {
    let state = DeviceBindingState.signing(with: InMemoryDeviceKeyStore(), sharesToken: true)

    #expect(await state.current() == .notSigning(.sharedToken))
  }

  @Test
  func aRuntimeWithoutAKeyDoesNotSign() async {
    #expect(await DeviceBindingState.neverSigning.current() == .notSigning(.keyUnavailable))
  }

  @Test
  func aLoadedKeySigns() async {
    let state = DeviceBindingState.signing(with: InMemoryDeviceKeyStore(), sharesToken: false)

    #expect(await state.current() == .signing)
  }

  @Test
  func aKeyThatCannotLoadIsUnavailable() async {
    let state = DeviceBindingState.signing(with: UnloadableDeviceKeyStore(), sharesToken: false)

    #expect(await state.current() == .notSigning(.keyUnavailable))
  }

  @Test
  func aSlowLoadTimesOutAndCountsOnce() async {
    let store = SlowDeviceKeyStore()
    let state = DeviceBindingState.signing(with: store, sharesToken: false)

    #expect(await state.current(wait: .milliseconds(20)) == .notSigning(.timeout))
    #expect(await state.current(wait: .milliseconds(20)) == .notSigning(.timeout))
    await state.recordSignFailure(.notALoss)
    #expect(await state.current(wait: .milliseconds(20)) == .notSigning(.timeout))

    store.finishLoading()
    #expect(await bindingBecomes(.signing, in: state))
  }

  @Test
  func aLoadStillPendingAtTheGiveUpStopsSigningUntilItCompletes() async {
    let store = SlowDeviceKeyStore()
    let state = DeviceBindingState(holder: DeviceKeyHolder(store: store), sharesToken: false, keyLoadGiveUp: .zero)

    #expect(await state.current(wait: .milliseconds(20)) == .notSigning(.keyUnavailable))

    store.finishLoading()
    #expect(await bindingBecomes(.signing, in: state))
  }

  @Test
  func threeTransientSignFailuresInARowStopSigning() async {
    let state = DeviceBindingState.signing(with: InMemoryDeviceKeyStore(), sharesToken: false)
    #expect(await state.current() == .signing)

    for _ in 0 ..< DeviceBindingState.transientFailuresBeforeUnsigned {
      await state.recordSignFailure(.notALoss)
    }

    #expect(await state.current() == .notSigning(.keyUnavailable))
  }

  @Test
  func aSignatureBetweenFailuresResetsTheCount() async {
    let state = DeviceBindingState.signing(with: InMemoryDeviceKeyStore(), sharesToken: false)
    #expect(await state.current() == .signing)

    await state.recordSignFailure(.notALoss)
    await state.recordSignFailure(.notALoss)
    await state.recordSigned()
    await state.recordSignFailure(.notALoss)
    await state.recordSignFailure(.keyLost)

    #expect(await state.current() == .signing)
  }
}

private func bindingBecomes(_ expected: DeviceBinding, in state: DeviceBindingState) async -> Bool {
  let deadline = ContinuousClock.now.advanced(by: .seconds(5))
  while ContinuousClock.now < deadline {
    if await state.current(wait: .zero) == expected {
      return true
    }
    try? await Task.sleep(for: .milliseconds(5))
  }
  return false
}

struct UnloadableDeviceKeyStore: DeviceKeyStore {
  func loadOrCreate() throws -> any DeviceKey {
    throw DeviceKeyError.keychain(errSecInteractionNotAllowed)
  }

  func hasStoredKey() throws -> Bool {
    false
  }

  func delete() throws {}
}

final class SlowDeviceKeyStore: DeviceKeyStore, @unchecked Sendable {
  private let loaded = DispatchSemaphore(value: 0)
  private let store = InMemoryDeviceKeyStore()

  func finishLoading() {
    loaded.signal()
  }

  func loadOrCreate() throws -> any DeviceKey {
    loaded.wait()
    loaded.signal()
    return try store.loadOrCreate()
  }

  func hasStoredKey() throws -> Bool {
    try store.hasStoredKey()
  }

  func delete() throws {
    try store.delete()
  }
}
