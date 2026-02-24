//
//  SessionTaskHeaderSection.swift
//

#if os(iOS)

import SwiftUI

struct SessionTaskHeaderSection: View {
  let title: LocalizedStringKey
  let subtitle: LocalizedStringKey

  var body: some View {
    VStack(spacing: 24) {
      Badge(key: "Two-step verification setup", style: .secondary)

      VStack(spacing: 8) {
        HeaderView(style: .title, text: title)
        HeaderView(style: .subtitle, text: subtitle)
      }
    }
  }
}

#endif
