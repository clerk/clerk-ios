//
//  ClerkFonts.swift
//  Clerk
//
//  Created by Mike Pitre on 4/10/25.
//

#if os(iOS)

import SwiftUI

public extension ClerkTheme {
  struct Fonts {
    // Text styles matching iOS system font styles
    public var largeTitle: Font
    public var title: Font
    public var title2: Font
    public var title3: Font
    public var headline: Font
    public var subheadline: Font
    public var body: Font
    public var callout: Font
    public var footnote: Font
    public var caption: Font
    public var caption2: Font

    // Initializer with individual fonts
    public init(
      largeTitle: Font = Self.default.largeTitle,
      title: Font = Self.default.title,
      title2: Font = Self.default.title2,
      title3: Font = Self.default.title3,
      headline: Font = Self.default.headline,
      subheadline: Font = Self.default.subheadline,
      body: Font = Self.default.body,
      callout: Font = Self.default.callout,
      footnote: Font = Self.default.footnote,
      caption: Font = Self.default.caption,
      caption2: Font = Self.default.caption2
    ) {
      self.largeTitle = largeTitle
      self.title = title
      self.title2 = title2
      self.title3 = title3
      self.headline = headline
      self.subheadline = subheadline
      self.body = body
      self.callout = callout
      self.footnote = footnote
      self.caption = caption
      self.caption2 = caption2
    }

    // Convenience initializer with just a font family
    public init(fontFamily: String) {
      largeTitle = .custom(fontFamily, size: 34, relativeTo: .largeTitle)
      title = .custom(fontFamily, size: 28, relativeTo: .title)
      title2 = .custom(fontFamily, size: 22, relativeTo: .title2)
      title3 = .custom(fontFamily, size: 20, relativeTo: .title3)
      headline = .custom(fontFamily, size: 17, relativeTo: .headline).weight(.semibold)
      subheadline = .custom(fontFamily, size: 15, relativeTo: .subheadline)
      body = .custom(fontFamily, size: 17, relativeTo: .body)
      callout = .custom(fontFamily, size: 16, relativeTo: .callout)
      footnote = .custom(fontFamily, size: 13, relativeTo: .footnote)
      caption = .custom(fontFamily, size: 12, relativeTo: .caption)
      caption2 = .custom(fontFamily, size: 11, relativeTo: .caption2)
    }
  }
}

public extension ClerkTheme.Fonts {
  nonisolated static var `default`: Self {
    .init(
      largeTitle: .system(.largeTitle),
      title: .system(.title),
      title2: .system(.title2),
      title3: .system(.title3),
      headline: .system(.headline),
      subheadline: .system(.subheadline),
      body: .system(.body),
      callout: .system(.callout),
      footnote: .system(.footnote),
      caption: .system(.caption),
      caption2: .system(.caption2)
    )
  }
}

#endif
