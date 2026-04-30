//
//  OrganizationSwitcherNavigation.swift
//

#if os(iOS)

import Observation

@MainActor
@Observable
final class OrganizationSwitcherSheetNavigation {
  var summaryIsPresented = false
  var presentedSheet: OrganizationSwitcher.PresentedSheet?
}

#endif
