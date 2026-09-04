# UI snapshots

Run snapshots on iOS 26.5 with Xcode 26.5, matching CI:

```sh
IOS_SIMULATOR_DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' make test-ui
```

`AuthFooterSnapshotTests` renders the production auth footer in a clipped 393 × 160 point container at 3× scale, with a fixed locale, appearance, and Dynamic Type size. The zero-inset cases cover hosts with no bottom safe area. The 34-point inset case preserves the 8-point downward label offset above the home indicator.

`NativeFooterSnapshotTests` protects the native appearance in dark portrait and light landscape auth layouts, organization screen footers, and the compact organization sheet's inline footer. The compact sheet intentionally uses `SecuredByClerkFooter(showBackground: false)`. Auth and compact-sheet references preserve their existing native appearance. The shared user-profile and organization footer aligns its two text rows with AuthView’s development-mode label, using the same inset-aware 8-point offset.

`FooterEmbeddingSnapshotTests` compares embedded footers against those same native references after a parent consumes all or half of the host's bottom safe area. It verifies the complete label, pattern, and bottom-line arrangement for auth and the shared footer used by user-profile and organization screens. The host inset is supplied through `clerkFooterHostBottomInset`, since `ImageRenderer` has no UIKit hosting-controller hierarchy.

`FooterHostSafeAreaTests` exercises the production footer modifier in UIKit windows with real hosting controllers and Auto Layout, without supplying a host-inset override. It covers native and safe-area-constrained views, tab bars, custom container padding, resizing, observer placement outside SwiftUI-owned content, cleanup, and isolation from a presenting controller. The package test runner has no window scene, so the presentation-isolation case attaches the presented view explicitly.

`FooterTabViewTests` hosts the actual `AuthView` and `UserProfileView` in a SwiftUI `TabView`. It compares the development label's accessibility bounds with the rendered tab bar's top edge, catching overlap that inset measurements and isolated footer snapshots cannot detect. The tab-bar snapshots use an 83-point container inset with a 34-point host inset. They preserve the native text-to-pattern spacing while keeping the complete footer above the bar, leaving the bar's area clear.

Snapshots use SwiftUI's `ImageRenderer` and compare PNG data without a third-party dependency. Every case attaches its actual image to the test result; mismatches also attach the expected image. To update an intentional visual change, review the attachments in Xcode's test report, export the actual image, and replace the corresponding PNG under `AuthFooter/` or `NativeFooter/`. Rerun the tests after reviewing the updated baselines.
