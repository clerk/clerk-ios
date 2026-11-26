//
//  DeviceBinding.swift
//  Clerk
//

import Foundation

enum DeviceBinding: Equatable {
  case signing
  case notSigning(Reason)

  enum Reason: Equatable {
    case sharedToken
    case frameworkHost
    case keyUnavailable
    case timeout
  }
}

enum FrameworkHost {
  static let header = "x-clerk-host-sdk"

  static func sent(_ request: URLRequest) -> Bool {
    request.value(forHTTPHeaderField: header).nilIfEmpty != nil
  }
}

enum ProofDecision: Equatable {
  case sign
  case sendUnsigned
  case failRequest(Reason)

  enum Reason: Equatable {
    case keyNotReady
    case keyError
  }
}

enum SignFailure: Equatable {
  case keyLost
  case notALoss
}

func proofDecision(
  tokenHasCnf: Bool,
  binding: DeviceBinding,
  signFailure: SignFailure?
) -> ProofDecision {
  if binding == .signing, signFailure == nil {
    return .sign
  }
  if tokenHasCnf, let gap = transientGap(binding: binding, signFailure: signFailure) {
    return .failRequest(gap)
  }
  return .sendUnsigned
}

private func transientGap(binding: DeviceBinding, signFailure: SignFailure?) -> ProofDecision.Reason? {
  switch binding {
  case .signing:
    switch signFailure {
    case nil, .keyLost:
      nil
    case .notALoss:
      .keyError
    }
  case .notSigning(.sharedToken), .notSigning(.frameworkHost), .notSigning(.keyUnavailable):
    nil
  case .notSigning(.timeout):
    .keyNotReady
  }
}

enum DeviceTokenClaims {
  static func hasCnf(_ token: String) -> Bool {
    (try? decode(jwt: token))?.body["cnf"] != nil
  }
}

enum DeviceBindingRequestError: Error, Equatable {
  case proofUnavailable(ProofDecision.Reason)
}

actor DeviceBindingState {
  static let keyWait: Duration = .seconds(5)
  static let keyLoadGiveUp: Duration = .seconds(15)
  static let transientFailuresBeforeUnsigned = 3

  nonisolated let holder: DeviceKeyHolder?
  nonisolated let sharesToken: Bool
  private let keyLoadGiveUp: Duration
  private var load: KeyLoad = .notStarted
  private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]
  private var transientFailuresInARow = 0

  private enum KeyLoad {
    case notStarted
    case pending(startedAt: ContinuousClock.Instant, timedOutOnce: Bool)
    case gaveUp
    case completed
  }

  init(holder: DeviceKeyHolder?, sharesToken: Bool, keyLoadGiveUp: Duration = DeviceBindingState.keyLoadGiveUp) {
    self.holder = holder
    self.sharesToken = sharesToken
    self.keyLoadGiveUp = keyLoadGiveUp
  }

  static func signing(with store: any DeviceKeyStore, sharesToken: Bool) -> DeviceBindingState {
    DeviceBindingState(holder: DeviceKeyHolder(store: store), sharesToken: sharesToken)
  }

  static var neverSigning: DeviceBindingState {
    DeviceBindingState(holder: nil, sharesToken: false)
  }

  func startLoading() {
    guard case .notStarted = load, !sharesToken, let holder else { return }
    load = .pending(startedAt: .now, timedOutOnce: false)
    Task.detached { [weak self] in
      _ = holder.state()
      await self?.loadCompleted()
    }
  }

  func current(wait: Duration = DeviceBindingState.keyWait) async -> DeviceBinding {
    if sharesToken {
      return .notSigning(.sharedToken)
    }
    guard let holder else {
      return .notSigning(.keyUnavailable)
    }
    startLoading()
    giveUpIfTooLong()
    if !stoppedSigning, case .pending(_, timedOutOnce: false) = load {
      await waitForLoad(upTo: wait)
      countTimeoutIfStillPending()
    }

    if stoppedSigning || holder.loadedState?.isUnavailable == true {
      return .notSigning(.keyUnavailable)
    }
    guard case .completed = load else {
      return .notSigning(.timeout)
    }
    return .signing
  }

  func recordSigned() {
    resetTransientFailures()
  }

  func recordSignFailure(_ failure: SignFailure) {
    if failure == .notALoss {
      countTransientFailure()
    }
  }

  private var stoppedSigning: Bool {
    transientFailuresInARow >= Self.transientFailuresBeforeUnsigned
  }

  private func loadCompleted() {
    load = .completed
    resetTransientFailures()
    let resumed = waiters.values
    waiters.removeAll()
    resumed.forEach { $0.resume() }
  }

  private func waitForLoad(upTo wait: Duration) async {
    let id = UUID()
    let timeout = Task { [weak self] in
      try? await Task.sleep(for: wait)
      await self?.resumeWaiter(id)
    }
    await withCheckedContinuation { waiters[id] = $0 }
    timeout.cancel()
  }

  private func resumeWaiter(_ id: UUID) {
    waiters.removeValue(forKey: id)?.resume()
  }

  private func countTimeoutIfStillPending() {
    giveUpIfTooLong()
    guard case let .pending(startedAt, timedOutOnce: false) = load else { return }
    load = .pending(startedAt: startedAt, timedOutOnce: true)
    countTransientFailure()
  }

  private func giveUpIfTooLong() {
    guard case let .pending(startedAt, _) = load, startedAt.duration(to: .now) >= keyLoadGiveUp else { return }
    load = .gaveUp
    if transientFailuresInARow < Self.transientFailuresBeforeUnsigned {
      transientFailuresInARow = Self.transientFailuresBeforeUnsigned
      ClerkLogger.warning("Device binding: not signing, the device key load was still pending at \(keyLoadGiveUp)")
    }
  }

  private func countTransientFailure() {
    transientFailuresInARow += 1
    if transientFailuresInARow == Self.transientFailuresBeforeUnsigned {
      ClerkLogger.warning(
        "Device binding: not signing after \(Self.transientFailuresBeforeUnsigned) transient key failures in a row"
      )
    }
  }

  private func resetTransientFailures() {
    if transientFailuresInARow >= Self.transientFailuresBeforeUnsigned {
      ClerkLogger.info("Device binding: the device key loaded, signing again")
    }
    transientFailuresInARow = 0
  }
}
