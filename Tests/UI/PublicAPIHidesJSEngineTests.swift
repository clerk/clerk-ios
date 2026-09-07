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
