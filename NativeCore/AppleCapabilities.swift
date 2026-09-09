import CryptoKit
import Foundation
import Security

public protocol CredentialStorage: Sendable {
  func read() async throws -> String?
  func write(_ value: String) async throws
  func remove() async throws
}

private final class SameOriginRedirects: NSObject, URLSessionTaskDelegate, Sendable {
  let origin: URL
  init(origin: URL) {
    self.origin = origin
  }

  func urlSession(_: URLSession, task _: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
    guard let url = request.url, url.scheme == "https", url.host == origin.host, url.port == origin.port else { completionHandler(nil); return }
    completionHandler(request)
  }
}

@MainActor public final class AppleCapabilities: NativeCapabilities {
  public typealias Presentation = @MainActor (String, JSONValue) async throws -> JSONValue
  private let storage: any CredentialStorage
  private let publishableKey: String
  private let origin: URL
  private let session: URLSession
  private let browser: Presentation?
  private let passkeys: Presentation?
  private let appleIdentity: Presentation?
  private let passkeyAutofill: Bool
  public var supported: [String] {
    ["http", "storage", "timer", "random"] + (passkeys != nil && passkeyAutofill ? ["passkeys.autofill"] : []) + (browser == nil ? [] : ["browser"]) + (passkeys == nil ? [] : ["passkeys"]) + (appleIdentity == nil ? [] : ["appleIdentity"])
  }

  public init(publishableKey: String, frontendAPI: URL, storage: any CredentialStorage, browser: Presentation? = nil, passkeys: Presentation? = nil, appleIdentity: Presentation? = nil, passkeyAutofill: Bool = false) throws {
    guard frontendAPI.scheme == "https", frontendAPI.host != nil, frontendAPI.user == nil, frontendAPI.password == nil else { throw CoreError(code: "invalid_frontend_api") }
    self.publishableKey = publishableKey
    origin = frontendAPI
    self.storage = storage
    self.browser = browser
    self.passkeys = passkeys
    self.appleIdentity = appleIdentity
    self.passkeyAutofill = passkeyAutofill
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.urlCache = nil
    session = URLSession(configuration: configuration, delegate: SameOriginRedirects(origin: frontendAPI), delegateQueue: nil)
  }

  public func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    try Task.checkCancellation()
    if capability == "browser", let browser { return try await browser(capability, arguments) }
    if capability.hasPrefix("passkeys."), let passkeys { return try await passkeys(capability, arguments) }
    if capability == "appleIdentity", let appleIdentity { return try await appleIdentity(capability, arguments) }
    let args = try arguments.object()
    switch capability {
    case "timer":
      let delay = try (args["milliseconds"] ?? .undefined).number()
      guard delay >= 0, delay <= 2_147_483_647 else { throw CoreError.invalidValue }
      try await Task.sleep(for: .milliseconds(delay))
      return .null
    case "storage.read", "storage.write", "storage.remove":
      guard args["scope"] == .string(publishableKey), args["key"] == .string("client") else { throw CoreError(code: "invalid_storage_scope") }
      if capability == "storage.read" { return try await storage.read().map(JSONValue.string) ?? .null }
      if capability == "storage.write" { try await storage.write((args["value"] ?? .undefined).string()) }
      else { try await storage.remove() }
      return .null
    case "http": return try await http(args)
    default: throw CoreError(code: "capability_unavailable")
    }
  }

  private func http(_ args: [String: JSONValue]) async throws -> JSONValue {
    let url = try (args["url"] ?? .undefined).url()
    guard url.scheme == "https", url.host == origin.host, url.port == origin.port, url.user == nil, url.password == nil else { throw CoreError(code: "invalid_http_origin") }
    var request = URLRequest(url: url)
    request.httpMethod = try (args["method"] ?? .undefined).string()
    request.httpShouldHandleCookies = false
    for (name, value) in try (args["headers"] ?? .object([:])).object() {
      let text = try value.string()
      guard !name.contains("\r"), !name.contains("\n"), !text.contains("\r"), !text.contains("\n"), name.lowercased() != "cookie" else { throw CoreError.invalidValue }
      request.setValue(text, forHTTPHeaderField: name)
    }
    if case .string(let body) = args["body"] { request.httpBody = Data(body.utf8) }
    else if case .object(let body) = args["body"] {
      let boundary = UUID().uuidString
      request.httpBody = try multipart(body["multipart"] ?? .undefined, boundary: boundary)
      request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    }
    let (body, response) = try await session.data(for: request)
    guard body.count <= 16 * 1024 * 1024, let response = response as? HTTPURLResponse, let text = String(data: body, encoding: .utf8) else { throw CoreError(code: "invalid_http_response") }
    var headers: [String: JSONValue] = [:]
    for (name, value) in response.allHeaderFields {
      headers[String(describing: name).lowercased()] = .string(String(describing: value))
    }
    return .object(["status": .number(Double(response.statusCode)), "headers": .object(headers), "body": .string(text)])
  }

  private func multipart(_ value: JSONValue, boundary: String) throws -> Data {
    func quote(_ text: String) -> String {
      text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: "")
    }
    var data = Data()
    func append(_ text: String) {
      data.append(Data(text.utf8))
    }
    for part in try value.array() {
      let p = try part.object()
      try append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(quote((p["name"] ?? .undefined).string()))\"")
      if let plain = p["value"] {
        try append("\r\n\r\n\(plain.string())\r\n")
      } else {
        let contentType = try (p["contentType"] ?? .undefined).string()
        guard !contentType.contains("\r"), !contentType.contains("\n") else { throw CoreError.invalidValue }
        try append("; filename=\"\(quote((p["filename"] ?? .undefined).string()))\"\r\nContent-Type: \(contentType)\r\n\r\n")
        try data.append(part.data())
        append("\r\n")
      }
    }
    append("--\(boundary)--\r\n")
    return data
  }
}
