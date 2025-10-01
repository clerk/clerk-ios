import Foundation
import Observation

@Observable
final class ConfigManager {
  struct State {
    enum Status {
      case idle
      case loading
      case loaded
      case failed(Error)
    }

    var status: Status
    var config: ConfigurationSnapshot?
  }

  private unowned let configurationStore: ConfigurationStore
  var options: ClerkOptions
  private(set) var state: State

  init(
    configurationStore: ConfigurationStore,
    options: ClerkOptions
  ) {
    self.configurationStore = configurationStore
    self.options = options
    self.state = State(status: .idle, config: nil)
  }

  @MainActor
  func load() async {
    if case .loading = state.status { return }

    state.status = .loading

    let snapshot = ConfigurationSnapshot(
      publishableKey: configurationStore.publishableKey,
      frontendAPIURL: configurationStore.frontendAPIURL,
      options: options
    )
    state = State(status: .loaded, config: snapshot)
  }
}

struct ConfigurationSnapshot {
  let publishableKey: String
  let frontendAPIURL: URL?
  let options: ClerkOptions
}
