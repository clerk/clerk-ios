//
//  OAuthProvider+IconImageUrl.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation
import SwiftUI

extension OAuthProvider {
  @MainActor
  func iconImageUrl(colorScheme: ColorScheme) -> URL? {
    guard let iconImageUrl else { return nil }

    guard colorScheme == .dark else {
      return iconImageUrl
    }

    return darkVariantIconImageUrl(for: iconImageUrl) ?? iconImageUrl
  }

  @MainActor
  var iconImageUrlsForPrefetch: Set<URL> {
    guard let iconImageUrl else { return [] }

    var urls = Set([iconImageUrl])

    if let darkVariantImageUrl = darkVariantIconImageUrl(for: iconImageUrl) {
      urls.insert(darkVariantImageUrl)
    }

    return urls
  }

  private func darkVariantIconImageUrl(for iconImageUrl: URL) -> URL? {
    guard !supportsTintedIconMask,
          let imageFileName = iconImageUrl.clerkStaticPngFileName
    else {
      return nil
    }

    let darkImageFileName: String? = switch self {
    case .custom:
      nil
    case .linkedinOidc:
      "linkedin-dark.png"
    default:
      "\(imageFileName.dropLast(4))-dark.png"
    }

    guard let darkImageFileName else { return nil }

    return iconImageUrl.replacingClerkStaticPngFileName(with: darkImageFileName)
  }
}

extension URL {
  fileprivate var clerkStaticPngFileName: String? {
    guard host?.caseInsensitiveCompare("img.clerk.com") == .orderedSame else {
      return nil
    }

    let lowercasedPath = path.lowercased()
    let fileName = lastPathComponent
    let lowercasedFileName = fileName.lowercased()
    guard lowercasedPath.hasPrefix("/static/"),
          lowercasedFileName.hasSuffix(".png"),
          !lowercasedFileName.hasSuffix("-dark.png")
    else {
      return nil
    }

    return fileName
  }

  fileprivate func replacingClerkStaticPngFileName(with darkImageFileName: String) -> URL? {
    guard let imageFileName = clerkStaticPngFileName,
          var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
    else {
      return nil
    }

    components.path = "\(components.path.dropLast(imageFileName.count))\(darkImageFileName)"
    return components.url
  }
}

#endif
