//
//  HostedAuth.swift
//  Clerk
//

import Foundation

/// The Account Portal screen shown when hosted authentication starts.
public enum HostedAuthMode: String, Codable, Sendable {
  /// Opens Account Portal on sign-in.
  case signIn = "sign-in"

  /// Opens Account Portal on sign-up.
  case signUp = "sign-up"
}

struct HostedAuthCreateParams: Encodable {
  let redirectUrl: String
  let codeChallenge: String
  let state: String
  let mode: HostedAuthMode?
}

struct HostedAuthRedeemParams: Encodable {
  let rotatingTokenNonce: String
  let codeVerifier: String
  let method = "GET"

  private enum CodingKeys: String, CodingKey {
    case rotatingTokenNonce
    case codeVerifier
    case method = "_method"
  }
}

struct HostedAuthResource: Codable {
  let object: String
  let url: String

  func authenticationUrl() throws -> URL {
    guard
      object == "hosted_auth",
      let components = URLComponents(string: url),
      let scheme = components.scheme?.lowercased(),
      let host = components.host,
      !host.isEmpty,
      components.user == nil,
      components.password == nil,
      let url = components.url,
      scheme == "https"
    else {
      throw ClerkClientError(message: "Hosted auth creation returned an invalid response.")
    }
    return url
  }
}

enum HostedAuthState {
  static func generate() throws -> String {
    let randomBytes = try SecureRandom.bytes(count: 16)
    return Data(randomBytes).base64EncodedString().base64URLFromBase64String()
  }
}

struct HostedAuthRedirect: Equatable {
  let rawValue: String
  private let components: URLComponents

  var callbackUrlScheme: String {
    components.scheme ?? ""
  }

  init(_ rawValue: String) throws {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      rawValue == trimmed,
      !rawValue.isEmpty,
      rawValue.contains("://"),
      let components = URLComponents(string: rawValue),
      let scheme = components.scheme,
      !scheme.isEmpty,
      components.url != nil,
      scheme.caseInsensitiveCompare("http") != .orderedSame,
      scheme.caseInsensitiveCompare("https") != .orderedSame
    else {
      throw ClerkClientError(message: "Hosted auth requires a valid custom-scheme redirect URL.")
    }

    self.rawValue = rawValue
    self.components = components
  }

  func matches(_ callbackUrl: URL) -> Bool {
    guard let callback = URLComponents(url: callbackUrl, resolvingAgainstBaseURL: false) else {
      return false
    }

    return Self.caseInsensitiveEqual(components.scheme, callback.scheme)
      && components.percentEncodedUser == callback.percentEncodedUser
      && components.percentEncodedPassword == callback.percentEncodedPassword
      && Self.caseInsensitiveEqual(components.host, callback.host)
      && components.port == callback.port
      && components.percentEncodedPath == callback.percentEncodedPath
  }

  private static func caseInsensitiveEqual(_ lhs: String?, _ rhs: String?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
      true
    case (.some(let lhs), .some(let rhs)):
      lhs.caseInsensitiveCompare(rhs) == .orderedSame
    default:
      false
    }
  }
}

struct HostedAuthCallback: Equatable {
  let rotatingTokenNonce: String
  let createdSessionId: String

  init(url: URL, redirect: HostedAuthRedirect, state: String) throws {
    guard redirect.matches(url) else {
      throw ClerkClientError(message: "Hosted auth callback URL did not match the initiated redirect URL.")
    }

    let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    guard Self.singleValue(named: "state", in: queryItems) == state else {
      throw ClerkClientError(message: "Hosted auth callback state did not match the initiated state.")
    }
    guard let rotatingTokenNonce = Self.nonEmptySingleValue(named: "rotating_token_nonce", in: queryItems) else {
      throw ClerkClientError(message: "Hosted auth callback did not include a rotating token nonce.")
    }
    guard let createdSessionId = Self.nonEmptySingleValue(named: "created_session_id", in: queryItems) else {
      throw ClerkClientError(message: "Hosted auth callback did not include the created session.")
    }

    self.rotatingTokenNonce = rotatingTokenNonce
    self.createdSessionId = createdSessionId
  }

  private static func nonEmptySingleValue(named name: String, in queryItems: [URLQueryItem]) -> String? {
    guard let value = singleValue(named: name, in: queryItems), !value.isEmpty else {
      return nil
    }
    return value
  }

  private static func singleValue(named name: String, in queryItems: [URLQueryItem]) -> String? {
    let matches = queryItems.filter { $0.name == name }
    guard matches.count == 1 else { return nil }
    return matches[0].value
  }
}
