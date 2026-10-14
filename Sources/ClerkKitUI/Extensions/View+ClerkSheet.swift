//
//  View+ClerkSheet.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

/// Sheets in Designed for iPad and Mac Catalyst apps don't inherit the presenter's observable environment objects.
struct ClerkUIContext: DynamicProperty {
  @Environment(Clerk.self) private var clerk: Clerk?
  @Environment(CodeLimiter.self) private var codeLimiter: CodeLimiter?
  @Environment(AuthState.self) private var authState: AuthState?
  @Environment(AuthNavigation.self) private var authNavigation: AuthNavigation?
  @Environment(UserProfileSheetNavigation.self) private var userProfileSheetNavigation: UserProfileSheetNavigation?
  @Environment(UserProfileBuiltInRouter.self) private var userProfileBuiltInRouter: UserProfileBuiltInRouter?
  @Environment(OrganizationProfileBuiltInRouter.self) private var organizationProfileBuiltInRouter: OrganizationProfileBuiltInRouter?

  func carry(into content: some View) -> some View {
    content
      .environment(clerk)
      .environment(codeLimiter)
      .environment(authState)
      .environment(authNavigation)
      .environment(userProfileSheetNavigation)
      .environment(userProfileBuiltInRouter)
      .environment(organizationProfileBuiltInRouter)
  }
}

private struct ClerkSheetModifier<SheetContent: View>: ViewModifier {
  @Binding var isPresented: Bool
  let onDismiss: (() -> Void)?
  let sheetContent: () -> SheetContent
  private var context = ClerkUIContext()

  init(isPresented: Binding<Bool>, onDismiss: (() -> Void)?, sheetContent: @escaping () -> SheetContent) {
    _isPresented = isPresented
    self.onDismiss = onDismiss
    self.sheetContent = sheetContent
  }

  func body(content: Content) -> some View {
    content.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
      context.carry(into: sheetContent())
    }
  }
}

private struct ClerkItemSheetModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
  @Binding var item: Item?
  let onDismiss: (() -> Void)?
  let sheetContent: (Item) -> SheetContent
  private var context = ClerkUIContext()

  init(item: Binding<Item?>, onDismiss: (() -> Void)?, sheetContent: @escaping (Item) -> SheetContent) {
    _item = item
    self.onDismiss = onDismiss
    self.sheetContent = sheetContent
  }

  func body(content: Content) -> some View {
    content.sheet(item: $item, onDismiss: onDismiss) { item in
      context.carry(into: sheetContent(item))
    }
  }
}

extension View {
  func clerkSheet(
    isPresented: Binding<Bool>,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping () -> some View
  ) -> some View {
    modifier(ClerkSheetModifier(isPresented: isPresented, onDismiss: onDismiss, sheetContent: content))
  }

  func clerkSheet<Item: Identifiable>(
    item: Binding<Item?>,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Item) -> some View
  ) -> some View {
    modifier(ClerkItemSheetModifier(item: item, onDismiss: onDismiss, sheetContent: content))
  }
}

#endif
