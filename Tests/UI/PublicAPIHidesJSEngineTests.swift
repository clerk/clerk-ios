import Foundation
import Testing

@Test func packageProductsOmitClerkJSCore() throws {
  let tests = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let package = try String(
    contentsOf: tests.appendingPathComponent("Package.swift"),
    encoding: .utf8
  )
  #expect(!package.contains(".library(name: \"ClerkJSCore\""))
  #expect(!package.contains(".library(name: \"ClerkSnapshots\""))
}

@Test func exampleHostsDoNotImportClerkJSCore() throws {
  let examples = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Examples")
  var imports: [String] = []
  let enumerator = FileManager.default.enumerator(
    at: examples,
    includingPropertiesForKeys: [.isRegularFileKey]
  )
  while let url = enumerator?.nextObject() as? URL {
    guard url.pathExtension == "swift" else { continue }
    let text = try String(contentsOf: url, encoding: .utf8)
    if text.contains("import ClerkJSCore") || text.contains("ClerkJSCore.") {
      imports.append(url.path)
    }
  }
  #expect(imports.isEmpty, "Hosts imported ClerkJSCore: \(imports)")
}

@Test func kitPublicSourcesDoNotImportClerkJSCore() throws {
  let sources = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Sources/ClerkKit")
  var leaks: [String] = []
  let enumerator = FileManager.default.enumerator(
    at: sources,
    includingPropertiesForKeys: [.isRegularFileKey]
  )
  while let url = enumerator?.nextObject() as? URL {
    guard url.pathExtension == "swift" else { continue }
    if url.deletingLastPathComponent().path == sources.appendingPathComponent("Core/JavaScript").path {
      continue
    }
    let text = try String(contentsOf: url, encoding: .utf8)
    if text.contains("import ClerkJSCore") || text.contains("ClerkJSHost") {
      leaks.append(url.path)
    }
  }
  #expect(leaks.isEmpty, "Public Kit sources imported the JS host: \(leaks)")
}

@Test func uiComponentsDoNotImportClerkJSCore() throws {
  let sources = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Sources/ClerkKitUI")
  var leaks: [String] = []
  for folder in ["Components", "Common"] {
    let root = sources.appendingPathComponent(folder)
    let enumerator = FileManager.default.enumerator(
      at: root,
      includingPropertiesForKeys: [.isRegularFileKey]
    )
    while let url = enumerator?.nextObject() as? URL {
      guard url.pathExtension == "swift" else { continue }
      let text = try String(contentsOf: url, encoding: .utf8)
      if text.contains("import ClerkJSCore")
        || text.contains("ClerkJSCore.")
        || text.contains("jsClerk")
        || text.contains("clerkEngineAttached")
        || text.contains("ClerkEngineBootstrap")
        || text.contains("ClerkJS")
      {
        leaks.append(url.path)
      }
    }
  }
  #expect(leaks.isEmpty, "UI components imported the JS engine: \(leaks)")
}
