//
//  OrganizationScopedStore.swift
//

import Foundation
import Observation

@MainActor
protocol OrganizationScopedContent: AnyObject, Observable {
  associatedtype Scope: Equatable & Sendable

  var scope: Scope { get }
  func start()
  func retire()
}

@MainActor
@Observable
final class OrganizationScopedStore<Content: OrganizationScopedContent> {
  private var content: Content?
  @ObservationIgnored private let make: @MainActor (Content.Scope) -> Content

  init(make: @escaping @MainActor (Content.Scope) -> Content) {
    self.make = make
  }

  var boundScope: Content.Scope? {
    content?.scope
  }

  func bind(_ scope: Content.Scope?) {
    guard scope != content?.scope else { return }

    content?.retire()
    content = scope.map(make)
    content?.start()
  }

  func content(for scope: Content.Scope?) -> Content? {
    guard let scope, let content, content.scope == scope else { return nil }
    return content
  }
}
