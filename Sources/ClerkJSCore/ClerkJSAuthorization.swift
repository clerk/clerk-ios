import Foundation
#if !os(watchOS)
@preconcurrency import JavaScriptCore
#endif

/// Independent of the stateful Clerk engine so retained snapshots can be queried synchronously.
/// The bundle contains only the shared pure authorization functions.
public enum ClerkJSAuthorization {
  public static func evaluate(_ method: String, arguments: [Data]) throws -> Data {
    #if os(watchOS)
    throw ClerkJSCoreError.unsupportedPlatform
    #else
    return try evaluator.evaluate(method, arguments: arguments)
    #endif
  }

  #if !os(watchOS)
  private static let evaluator = Evaluator()

  private final class Evaluator: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.clerk.authorization")
    private var context: JSContext?

    func evaluate(_ method: String, arguments: [Data]) throws -> Data {
      try queue.sync {
        if context == nil {
          let context = JSContext()!
          let atob: @convention(block) (String) -> String = { value in
            var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
            return Data(base64Encoded: base64).map { String(decoding: $0, as: UTF8.self) } ?? ""
          }
          context.setObject(atob, forKeyedSubscript: "atob" as NSString)
          guard let url = Bundle.module.url(forResource: "clerk.authorization", withExtension: "js") else {
            throw ClerkJSCoreError.missingBundle
          }
          try context.evaluateScript(String(contentsOf: url, encoding: .utf8), withSourceURL: url)
          if let error = context.exception { throw ClerkJSCoreError.javascript(error.toString()) }
          self.context = context
        }
        guard let context else { throw ClerkJSCoreError.missingBundle }
        context.exception = nil
        let values = try arguments.map { try JSONSerialization.jsonObject(with: $0, options: .fragmentsAllowed) }
        let result = context.objectForKeyedSubscript("ClerkAuthorization")?.invokeMethod(method, withArguments: values)
        if let error = context.exception { throw ClerkJSCoreError.javascript(error.toString()) }
        guard let object = result?.toObject() else { throw ClerkJSCoreError.invalidArgument("authorization result") }
        return try JSONSerialization.data(withJSONObject: object, options: .fragmentsAllowed)
      }
    }
  }
  #endif
}
