//
//  QueryItemMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

struct QueryItemMiddleware {

  static func process(_ request: inout URLRequest) {
    request.url?.append(queryItems: [.init(name: "_is_native", value: "true")])
  }

}
