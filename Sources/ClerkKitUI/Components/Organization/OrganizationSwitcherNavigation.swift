//
//  OrganizationSwitcherNavigation.swift
//

#if os(iOS)

import Observation

@MainActor
@Observable
final class OrganizationSwitcherSheetNavigation {
  var overviewIsPresented = false
  var presentedSheet: OrganizationSwitcher.PresentedSheet?
}

#endif
