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

  static func loadIfNeeded(_ clerk: ClerkJSCore.Clerk, key: String) async {
    if let existing = loadTasks[key] {
      try? await existing.value
      return
    }
    let task = Task {
      try await clerk.load()
    }
    loadTasks[key] = task
    do {
      try await task.value
    } catch {
      loadTasks[key] = nil
    }
  }
}

struct ClerkRuntimeContainer<Content: View>: View {
  @SwiftUI.Environment(ClerkKit.Clerk.self) private var clerk
  @State private var engine: ClerkJSCore.Clerk?
  private let content: (ClerkJSCore.Clerk) -> Content

  init(@ViewBuilder content: @escaping (ClerkJSCore.Clerk) -> Content) {
    self.content = content
  }

  var body: some View {
    let resolved = engine ?? ClerkRuntimeStore.shared(for: clerk.publishableKey)
    content(resolved)
      .environment(resolved)
      .task(id: clerk.publishableKey) {
        let created = ClerkRuntimeStore.shared(for: clerk.publishableKey)
        engine = created
        await ClerkRuntimeStore.loadIfNeeded(created, key: clerk.publishableKey)
      }
  }
}

#endif
