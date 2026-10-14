#if os(iOS)

import ClerkKit
@testable import ClerkKitUI
import Foundation
import SwiftUI
import Testing

@MainActor
struct OrganizationAdvisoryMessageTests {
  private let alreadyExists = try! JSONDecoder().decode(
    OrganizationCreationDefaults.Advisory.self,
    from: Data(#"{"code": "organization_already_exists", "meta": {"organization_name": "Acme", "organization_domain": "acme.com"}}"#.utf8)
  )

  @Test(arguments: [
    ("en", "An organization already exists for the detected company name (Acme) and acme.com. Join by invitation."),
    ("es", "Ya existe una organización para el nombre de empresa detectado (Acme) y acme.com. Únete por invitación."),
    ("de", "Für den erkannten Firmennamen (Acme) und acme.com existiert bereits eine Organisation. Treten Sie per Einladung bei."),
  ])
  func alreadyExistsWarningIsTranslated(language: String, expected: String) throws {
    let message = try #require(OrganizationProfileFormView.advisoryMessage(for: alreadyExists))

    let rendered = try render(WarningText(message, bundle: .module), language: language)
    let reference = try render(WarningText(verbatim: expected), language: language)

    #expect(rendered.pngData() == reference.pngData())
  }

  @Test
  func unknownAdvisoryShowsNoWarning() {
    var advisory = alreadyExists
    advisory.code = "something_else"

    #expect(OrganizationProfileFormView.advisoryMessage(for: advisory) == nil)
  }

  private func render(_ view: some View, language: String) throws -> UIImage {
    let renderer = ImageRenderer(content: view.environment(\.locale, Locale(identifier: language)))
    renderer.proposedSize = ProposedViewSize(width: 390, height: nil)
    renderer.scale = 2
    return try #require(renderer.uiImage)
  }
}

#endif
