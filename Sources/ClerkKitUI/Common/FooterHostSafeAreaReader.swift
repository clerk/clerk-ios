#if os(iOS)

import SwiftUI
import UIKit

struct FooterHostSafeAreaReader: UIViewRepresentable {
  let onChange: (CGFloat) -> Void

  func makeUIView(context _: Context) -> FooterHostSafeAreaView {
    let view = FooterHostSafeAreaView()
    view.isUserInteractionEnabled = false
    view.onChange = onChange
    return view
  }

  func updateUIView(_ uiView: FooterHostSafeAreaView, context _: Context) {
    uiView.onChange = onChange
    uiView.setNeedsLayout()
  }

  static func dismantleUIView(_ uiView: FooterHostSafeAreaView, coordinator _: ()) {
    uiView.stopObserving()
  }
}

final class FooterHostSafeAreaView: UIView {
  var onChange: ((CGFloat) -> Void)?
  private var lastInset: CGFloat?
  private weak var observedController: UIViewController?
  private let observer = FooterContainerSafeAreaView()
  private var observerConstraints: [NSLayoutConstraint] = []

  override func didMoveToWindow() {
    super.didMoveToWindow()
    updateObservation()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateObservation()
  }

  func stopObserving() {
    observer.onChange = nil
    NSLayoutConstraint.deactivate(observerConstraints)
    observerConstraints.removeAll()
    observer.removeFromSuperview()
    observedController = nil
    lastInset = nil
  }

  private func updateObservation() {
    guard window != nil,
          let controller = presentationController,
          let container = controller.viewIfLoaded,
          let superview = container.superview
    else {
      stopObserving()
      return
    }

    if observedController !== controller || observer.superview !== superview {
      stopObserving()
      observedController = controller
      observer.onChange = { [weak self] in self?.updateInset() }
      observer.isUserInteractionEnabled = false
      observer.isOpaque = false
      observer.translatesAutoresizingMaskIntoConstraints = false
      // Keep the observer outside SwiftUI's hosting view while tracking the presentation's bounds.
      superview.insertSubview(observer, aboveSubview: container)
      observerConstraints = [
        observer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        observer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        observer.topAnchor.constraint(equalTo: container.topAnchor),
        observer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      ]
      NSLayoutConstraint.activate(observerConstraints)
    }
    updateInset()
  }

  private func updateInset() {
    guard let window, let controller = observedController else { return }
    let hostInset = max(0, (controller.viewIfLoaded?.safeAreaInsets.bottom ?? 0) - controller.additionalSafeAreaInsets.bottom)
    let inset = min(hostInset, window.safeAreaInsets.bottom)
    guard lastInset != inset else { return }
    lastInset = inset
    DispatchQueue.main.async { [weak self] in
      guard let self, self.window != nil, lastInset == inset else { return }
      onChange?(inset)
    }
  }

  private var presentationController: UIViewController? {
    var responder: UIResponder? = self
    while let current = responder, !(current is UIViewController) {
      responder = current.next
    }
    guard var controller = responder as? UIViewController else { return nil }
    // Stop at the presentation root so a sheet never inherits its presenter's insets.
    while let parent = controller.parent {
      controller = parent
    }
    return controller
  }
}

final class FooterContainerSafeAreaView: UIView {
  var onChange: (() -> Void)?

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    onChange?()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    onChange?()
  }
}

#endif
