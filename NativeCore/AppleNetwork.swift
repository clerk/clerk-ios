import Foundation
import Network

/// A satisfied path permits HTTP; it is not a guarantee that Clerk is reachable.
private func startNetworkMonitor(_ receive: @escaping @Sendable (Bool) -> Void) -> @Sendable () -> Void {
  let monitor = NWPathMonitor()
  monitor.pathUpdateHandler = { receive($0.status == .satisfied) }
  monitor.start(queue: DispatchQueue(label: "com.clerk.network"))
  return { monitor.cancel() }
}

@MainActor func observeNetworkConnectivity(
  _ runtime: CoreRuntime,
  start: (@escaping @Sendable (Bool) -> Void) -> @Sendable () -> Void = startNetworkMonitor
) {
  let stop = start { [weak runtime] online in
    Task { @MainActor in runtime?.setNetworkOnline(online) }
  }
  runtime.addTeardown { stop() }
}
