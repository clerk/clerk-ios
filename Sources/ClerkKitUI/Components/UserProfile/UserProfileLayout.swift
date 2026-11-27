//
//  UserProfileLayout.swift
//  Clerk
//

#if os(iOS) || os(macOS)

/// How ``UserProfileView`` arranges its root list and the page it opens.
public enum UserProfileLayout: Sendable {
  /// Shows the root list beside the selected page when the view has a regular
  /// horizontal size class and is at least 700 points wide, such as full screen
  /// on iPad, and a single navigation stack otherwise. Sheets, iPhone, and views
  /// embedded with a `navigationPath` always use a single stack.
  case automatic

  /// Always shows a single navigation stack that pushes each page over the root list.
  case stack
}

#endif
