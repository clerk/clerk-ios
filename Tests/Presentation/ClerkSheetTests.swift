//
//  ClerkSheetTests.swift
//

#if os(macOS)

import AppKit
import ClerkKit
@testable import ClerkKitUI
import SwiftUI
import Testing

@MainActor
@Suite(.serialized)
struct ClerkSheetTests {
  @Test
  func sheetContentReadsTheClerkContextAndTheme() {
    let context = InjectedContext()
    let probe = ContextProbeLog()
    let window = hostOffscreen(
      SheetPresenter(probe: probe)
        .environment(\.clerkTheme.colors.primary, .red)
        .injecting(context)
    )
    defer { window.close() }

    runMainLoop { probe.reads != nil && !window.sheets.isEmpty }

    #expect(window.sheets.count == 1)
    #expect(probe.reads == context.expectedReads(themePrimary: .red))
  }

  @Test
  func carriedContextReachesContentHostedOutsideThePresenter() throws {
    let context = InjectedContext()
    let carriedProbe = ContextProbeLog()
    let carried = CarriedContentSlot()
    let presenterWindow = hostOffscreen(
      ContextCarrier(slot: carried, probe: carriedProbe)
        .injecting(context)
    )
    defer { presenterWindow.close() }
    runMainLoop { carried.view != nil }
    let carriedView = try #require(carried.view)

    let uncarriedProbe = ContextProbeLog()
    let uncarriedWindow = hostOffscreen(ContextProbe(log: uncarriedProbe))
    defer { uncarriedWindow.close() }
    runMainLoop { uncarriedProbe.reads != nil }
    #expect(uncarriedProbe.reads == ContextReads.empty)

    let carriedWindow = hostOffscreen(carriedView)
    defer { carriedWindow.close() }
    runMainLoop { carriedProbe.reads != nil }
    #expect(carriedProbe.reads == context.expectedReads(themePrimary: ClerkTheme.default.colors.primary))
  }

  @Test
  func itemSheetFromPushedDestinationReadsTheClerkContextAndTheme() {
    let context = InjectedContext()
    let probe = ContextProbeLog()
    let window = hostOffscreen(PushedSheetPresenter(context: context, probe: probe))
    defer { window.close() }

    runMainLoop { probe.reads != nil && !window.sheets.isEmpty }

    #expect(window.sheets.count == 1)
    #expect(probe.reads == context.expectedReads(themePrimary: .red))
  }

  @Test
  func sheetOwnedContextOverridesAbsentPresenterContext() {
    let context = InjectedContext()
    let probe = ContextProbeLog()
    let window = hostOffscreen(SheetOwnedContextPresenter(context: context, probe: probe))
    defer { window.close() }

    runMainLoop { probe.reads != nil && !window.sheets.isEmpty }

    #expect(window.sheets.count == 1)
    #expect(probe.reads == context.expectedReads(themePrimary: ClerkTheme.default.colors.primary))
  }

  @Test
  func presenterWithOnlyClerkDoesNotRequireUnrelatedModels() {
    let clerk = Clerk()
    let probe = ContextProbeLog()
    let window = hostOffscreen(SheetPresenter(probe: probe).environment(clerk))
    defer { window.close() }

    runMainLoop { probe.reads != nil && !window.sheets.isEmpty }

    #expect(window.sheets.count == 1)
    #expect(probe.reads == ContextReads(clerk: ObjectIdentifier(clerk), themePrimary: ClerkTheme.default.colors.primary))
  }
}

private struct ContextReads: Equatable {
  var clerk: ObjectIdentifier?
  var codeLimiter: ObjectIdentifier?
  var authState: ObjectIdentifier?
  var authNavigation: ObjectIdentifier?
  var userProfileSheetNavigation: ObjectIdentifier?
  var userProfileBuiltInRouter: ObjectIdentifier?
  var organizationProfileBuiltInRouter: ObjectIdentifier?
  var themePrimary: Color

  static let empty = ContextReads(themePrimary: ClerkTheme.default.colors.primary)
}

@MainActor
private final class ContextProbeLog {
  var reads: ContextReads?
}

@MainActor
private struct InjectedContext {
  let clerk = Clerk()
  let codeLimiter = CodeLimiter()
  let authState = AuthState()
  let authNavigation = AuthNavigation()
  let userProfileSheetNavigation = UserProfileSheetNavigation()
  let userProfileBuiltInRouter = UserProfileBuiltInRouter(push: { _ in }, dismissAction: { _ in })
  let organizationProfileBuiltInRouter = OrganizationProfileBuiltInRouter(push: { _ in }, dismissAction: { _ in })

  func expectedReads(themePrimary: Color) -> ContextReads {
    ContextReads(
      clerk: ObjectIdentifier(clerk),
      codeLimiter: ObjectIdentifier(codeLimiter),
      authState: ObjectIdentifier(authState),
      authNavigation: ObjectIdentifier(authNavigation),
      userProfileSheetNavigation: ObjectIdentifier(userProfileSheetNavigation),
      userProfileBuiltInRouter: ObjectIdentifier(userProfileBuiltInRouter),
      organizationProfileBuiltInRouter: ObjectIdentifier(organizationProfileBuiltInRouter),
      themePrimary: themePrimary
    )
  }
}

extension View {
  fileprivate func injecting(_ context: InjectedContext) -> some View {
    environment(context.clerk)
      .environment(context.codeLimiter)
      .environment(context.authState)
      .environment(context.authNavigation)
      .environment(context.userProfileSheetNavigation)
      .environment(context.userProfileBuiltInRouter)
      .environment(context.organizationProfileBuiltInRouter)
  }
}

private struct ContextProbe: View {
  let log: ContextProbeLog

  @Environment(Clerk.self) private var clerk: Clerk?
  @Environment(CodeLimiter.self) private var codeLimiter: CodeLimiter?
  @Environment(AuthState.self) private var authState: AuthState?
  @Environment(AuthNavigation.self) private var authNavigation: AuthNavigation?
  @Environment(UserProfileSheetNavigation.self) private var userProfileSheetNavigation: UserProfileSheetNavigation?
  @Environment(UserProfileBuiltInRouter.self) private var userProfileBuiltInRouter: UserProfileBuiltInRouter?
  @Environment(OrganizationProfileBuiltInRouter.self) private var organizationProfileBuiltInRouter: OrganizationProfileBuiltInRouter?
  @Environment(\.clerkTheme) private var theme

  var body: some View {
    Color.clear
      .frame(width: 120, height: 120)
      .onAppear {
        log.reads = ContextReads(
          clerk: clerk.map(ObjectIdentifier.init),
          codeLimiter: codeLimiter.map(ObjectIdentifier.init),
          authState: authState.map(ObjectIdentifier.init),
          authNavigation: authNavigation.map(ObjectIdentifier.init),
          userProfileSheetNavigation: userProfileSheetNavigation.map(ObjectIdentifier.init),
          userProfileBuiltInRouter: userProfileBuiltInRouter.map(ObjectIdentifier.init),
          organizationProfileBuiltInRouter: organizationProfileBuiltInRouter.map(ObjectIdentifier.init),
          themePrimary: theme.colors.primary
        )
      }
  }
}

private struct SheetPresenter: View {
  let probe: ContextProbeLog
  @State private var isPresented = false

  var body: some View {
    Color.clear
      .frame(width: 200, height: 200)
      .clerkSheet(isPresented: $isPresented) {
        ContextProbe(log: probe)
      }
      .onAppear { isPresented = true }
  }
}

private struct PushedSheetPresenter: View {
  let context: InjectedContext
  let probe: ContextProbeLog
  @State private var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      Color.clear
        .frame(width: 200, height: 200)
        .navigationDestination(for: Int.self) { _ in
          ItemSheetPresenter(probe: probe)
            .injecting(context)
        }
        .onAppear {
          if path.isEmpty { path.append(1) }
        }
    }
    .environment(\.clerkTheme.colors.primary, .red)
  }
}

private struct ItemSheetPresenter: View {
  struct Item: Identifiable {
    let id = 1
  }

  let probe: ContextProbeLog
  @State private var item: Item?

  var body: some View {
    Color.clear
      .frame(width: 200, height: 200)
      .clerkSheet(item: $item) { _ in
        ContextProbe(log: probe)
      }
      .onAppear { item = Item() }
  }
}

private struct SheetOwnedContextPresenter: View {
  let context: InjectedContext
  let probe: ContextProbeLog
  @State private var isPresented = false

  var body: some View {
    Color.clear
      .frame(width: 200, height: 200)
      .clerkSheet(isPresented: $isPresented) {
        ContextProbe(log: probe).injecting(context)
      }
      .onAppear { isPresented = true }
  }
}

@MainActor
private final class CarriedContentSlot {
  var view: AnyView?
}

private struct ContextCarrier: View {
  let slot: CarriedContentSlot
  let probe: ContextProbeLog
  private var context = ClerkUIContext()

  init(slot: CarriedContentSlot, probe: ContextProbeLog) {
    self.slot = slot
    self.probe = probe
  }

  var body: some View {
    Color.clear
      .frame(width: 200, height: 200)
      .onAppear {
        slot.view = AnyView(context.carry(into: ContextProbe(log: probe)))
      }
  }
}

@MainActor
private func hostOffscreen(_ view: some View) -> NSWindow {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 320, height: 320),
    styleMask: [.titled],
    backing: .buffered,
    defer: false
  )
  window.isReleasedWhenClosed = false
  window.contentViewController = NSHostingController(rootView: view)
  window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
  window.orderFront(nil)
  return window
}

@MainActor
private func runMainLoop(until condition: () -> Bool) {
  let deadline = Date.now.addingTimeInterval(5)
  while !condition(), Date.now < deadline {
    RunLoop.main.run(mode: .default, before: Date.now.addingTimeInterval(0.02))
  }
}

#endif
