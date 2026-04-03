//
//  ClerkURLRoute.swift
//  Clerk
//

import Foundation

enum ClerkURLRoute: Hashable {
  case magicLink(flowId: String, approvalToken: String)
}
