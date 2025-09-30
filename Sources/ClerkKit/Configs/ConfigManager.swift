import Foundation
import Observation

@MainActor
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

  private let fetcher: ConfigFetching
  private(set) var state: State

  init(fetcher: ConfigFetching) {
    self.fetcher = fetcher
    self.state = State(status: .idle, config: nil)
  }

  func load() async {
    if case .loading = state.status { return }

    state.status = .loading

    do {
      let snapshot = try await fetcher.fetchConfiguration()
      state = State(status: .loaded, config: snapshot)
    } catch {
      state = State(status: .failed(error), config: state.config)
    }
  }
}

protocol ConfigFetching {
  func fetchConfiguration() async throws -> ConfigurationSnapshot
}

struct ConfigurationSnapshot: Equatable {
  let publishableKey: String
  let frontendAPIURL: URL?
  let options: ClerkOptions
}

final class DefaultConfigFetcher: ConfigFetching {
  private unowned let configurationStore: ConfigurationStore
  private let optionsProvider: () -> ClerkOptions

  init(
    configurationStore: ConfigurationStore,
    optionsProvider: @escaping () -> ClerkOptions
  ) {
    self.configurationStore = configurationStore
    self.optionsProvider = optionsProvider
  }

  func fetchConfiguration() async throws -> ConfigurationSnapshot {
    ConfigurationSnapshot(
      publishableKey: configurationStore.publishableKey,
      frontendAPIURL: configurationStore.frontendAPIURL,
      options: optionsProvider()
    )
  }
}
