//
//  UserProfileLayout.swift
//  Clerk
//

#if os(iOS) || os(macOS)

/// How ``UserProfileView`` arranges its root list and the page it opens.
public enum UserProfileLayout: Sendable {
  /// Shows the root list beside the selected page when the view has a regular
  /// horizontal size class and is at least 700 points wide, such as full screen
  /// on iPad, on an open iPhone Duo, or on a large iPhone in landscape, and a
  /// single navigation stack otherwise. Views embedded with a `navigationPath`
  /// always use a single stack, and so do most sheets.
  ///
  /// A view in a column of your own `NavigationSplitView` can't tell that it
  /// is inside one, so when that column has a regular size class and is at
  /// least 700 points wide it shows its own split there. Pass ``stack`` in
  /// that case.
  case automatic

  /// Always shows a single navigation stack that pushes each page over the root list.
  case stack
}

#endif
