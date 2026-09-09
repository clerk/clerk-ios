import ClerkKit

extension CoreResource {
  @MainActor var coreOwner: Clerk? {
    try? context.requireRuntime().root("clerk", as: Clerk.self)
  }
}
