#if os(iOS) || os(macOS)

import SwiftUI

struct FooterSafeArea {
  let containerInset: CGFloat
  let hostInset: CGFloat

  var additionalPadding: CGFloat {
    // A bar prevents background extension, so preserve that space inside the footer instead.
    hasBottomBar ? hostInset : max(0, hostInset - containerInset)
  }

  var developmentModeOffset: CGFloat {
    min(8, hostInset)
  }

  var backgroundSafeAreaEdges: Edge.Set {
    hasBottomBar ? [] : .bottom
  }

  private var hasBottomBar: Bool {
    containerInset > hostInset
  }
}

extension EnvironmentValues {
  @Entry var clerkFooterHostBottomInset: CGFloat?
}

#endif
