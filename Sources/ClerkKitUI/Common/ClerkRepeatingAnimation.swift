//
//  ClerkRepeatingAnimation.swift
//  Clerk
//

#if os(iOS)

import SwiftUI
import UIKit

struct ClerkRepeatingAnimation: UIViewRepresentable {
  let kind: ClerkRepeatingAnimationView.Kind
  let color: Color

  func makeUIView(context _: Context) -> ClerkRepeatingAnimationView {
    ClerkRepeatingAnimationView(kind: kind)
  }

  func updateUIView(_ view: ClerkRepeatingAnimationView, context _: Context) {
    view.kind = kind
    view.tintColor = UIColor(color)
    view.backgroundColor = kind.isCursor ? UIColor(color) : .clear
  }
}

final class ClerkRepeatingAnimationView: UIImageView {
  enum Kind: Equatable {
    case spinner
    case cursor(isOn: Bool)

    var isCursor: Bool {
      if case .cursor = self { return true }
      return false
    }
  }

  var kind: Kind {
    didSet {
      guard kind != oldValue else { return }
      layer.removeAnimation(forKey: Self.animationKey)
      startAnimationIfNeeded()
    }
  }

  private static let animationKey = "clerk.repeating"

  init(kind: Kind) {
    self.kind = kind
    let image = kind.isCursor ? nil : UIImage(named: "icon-spinner", in: .module, compatibleWith: nil)
    super.init(image: image?.withRenderingMode(.alwaysTemplate))
    contentMode = .scaleAspectFit
    isUserInteractionEnabled = false
    isAccessibilityElement = false
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(startAnimationIfNeeded),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      layer.removeAnimation(forKey: Self.animationKey)
    } else {
      startAnimationIfNeeded()
    }
  }

  @objc private func startAnimationIfNeeded() {
    guard window != nil, layer.animation(forKey: Self.animationKey) == nil else { return }
    let animation: CABasicAnimation
    switch kind {
    case .spinner:
      animation = CABasicAnimation(keyPath: "transform.rotation.z")
      animation.fromValue = 0
      animation.toValue = 2 * Double.pi
      animation.duration = 1
      animation.timingFunction = CAMediaTimingFunction(name: .linear)
    case .cursor(let isOn):
      let target: Float = isOn ? 1 : 0
      layer.opacity = target
      animation = CABasicAnimation(keyPath: "opacity")
      animation.fromValue = 1 - target
      animation.toValue = target
      animation.duration = 0.35 / 0.75
      animation.autoreverses = true
      animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    }
    animation.repeatCount = .infinity
    layer.add(animation, forKey: Self.animationKey)
  }
}

#endif
