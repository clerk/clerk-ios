#if os(iOS) || os(macOS)

import ClerkJSCore
import ClerkKit
import SwiftUI

@MainActor
enum ClerkRuntimeStore {
  private static var instances: [String: ClerkJSCore.Clerk] = [:]
  private static var loadTasks: [String: Task<Void, Error>] = [:]

  static func shared(for publishableKey: String) -> ClerkJSCore.Clerk {
    if let existing = instances[publishableKey] {
      return existing
    }
    let created = ClerkJSCore.Clerk.persistent(publishableKey: publishableKey)
    instances[publishableKey] = created
    return created
  }

  static func register(_ clerk: ClerkJSCore.Clerk, for publishableKey: String, alreadyLoaded: Bool) {
    instances[publishableKey] = clerk
    if alreadyLoaded {
      loadTasks[publishableKey] = Task {}
    }
  }

  static func loadIfNeeded(_ clerk: ClerkJSCore.Clerk, key: String, onto kit: ClerkKit.Clerk) async {
    if let existing = loadTasks[key] {
      try? await existing.value
      publish(clerk, onto: kit)
      return
    }
    let task = Task {
      try await clerk.load()
    }
    loadTasks[key] = task
    do {
      try await task.value
      publish(clerk, onto: kit)
    } catch {
      loadTasks[key] = nil
    }
  }

  static func publish(_ engine: ClerkJSCore.Clerk, onto kit: ClerkKit.Clerk) {
    guard let data = engine.lastClientJSON else { return }
    let payload = (try? FAPIJSON.normalizeClientJSON(data)) ?? data
    try? kit.applyEngineClientJSON(payload)
  }
}

struct ClerkRuntimeContainer<Content: View>: View {
  @SwiftUI.Environment(ClerkKit.Clerk.self) private var clerk
  @State private var engine: ClerkJSCore.Clerk?
  private let content: (ClerkJSCore.Clerk) -> Content

  init(@ViewBuilder content: @escaping (ClerkJSCore.Clerk) -> Content) {
    ClerkEngineBootstrap.install()
    self.content = content
  }

  var body: some View {
    let resolved = engine ?? ClerkRuntimeStore.shared(for: clerk.publishableKey)
    content(resolved)
      .environment(resolved)
      .task(id: clerk.publishableKey) {
        let created = ClerkRuntimeStore.shared(for: clerk.publishableKey)
        engine = created
        await ClerkRuntimeStore.loadIfNeeded(created, key: clerk.publishableKey, onto: clerk)
      }
      .onChange(of: resolved.user?.id) { _, _ in
        ClerkRuntimeStore.publish(resolved, onto: clerk)
      }
      .onChange(of: resolved.session.id) { _, _ in
        ClerkRuntimeStore.publish(resolved, onto: clerk)
      }
  }
}

#endif
