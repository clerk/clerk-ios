//
//  LoginMode.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/16/25.
//

/// The login modes supported by this app.
enum LoginMode: Hashable {
  case signIn(method: Method)
  case signUp(method: Method)

  enum Method: Hashable {
    case email
    case phone
  }

  var method: Method {
    switch self {
    case .signIn(let method), .signUp(let method):
      method
    }
  }
}
