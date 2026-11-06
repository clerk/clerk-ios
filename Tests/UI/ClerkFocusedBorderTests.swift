#if os(iOS)

@testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct ClerkFocusedBorderTests {
  @Test
  func verificationCodeErrorBorderAppearsAndClearsAfterTheShake() async throws {
    let model = Model()
    let controller = UIHostingController(rootView: CodeField(model: model))
    controller.overrideUserInterfaceStyle = .light
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = controller
    window.makeKeyAndVisible()
    controller.view.frame = window.bounds
    controller.view.layoutIfNeeded()
    defer { window.isHidden = true }

    try await Task.sleep(for: .seconds(1))
    #expect(try redPixelCount(in: window) == 0)

    model.state = .error
    try await Task.sleep(for: .seconds(1))
    let errorPixels = try redPixelCount(in: window)
    #expect(errorPixels > 500)

    model.state = .default
    try await Task.sleep(for: .seconds(1))
    #expect(try redPixelCount(in: window) == 0)
  }

  private func redPixelCount(in window: UIWindow) throws -> Int {
    let view = try #require(window.rootViewController?.view)
    view.layoutIfNeeded()
    let image = UIGraphicsImageRenderer(bounds: view.bounds).image { context in
      view.layer.render(in: context.cgContext)
    }
    Attachment.record(image, named: "Verification code border")
    let cgImage = try #require(image.cgImage)
    var pixels = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
    try pixels.withUnsafeMutableBytes { buffer in
      let context = try #require(CGContext(
        data: buffer.baseAddress,
        width: cgImage.width,
        height: cgImage.height,
        bitsPerComponent: 8,
        bytesPerRow: cgImage.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ))
      context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    }
    return stride(from: 0, to: pixels.count, by: 4).count {
      Int(pixels[$0]) > Int(pixels[$0 + 1]) + 40 && Int(pixels[$0]) > Int(pixels[$0 + 2]) + 40
    }
  }

  @Observable
  final class Model {
    var code = ""
    var state = OTPField.FieldState.default
  }

  private struct CodeField: View {
    @Bindable var model: Model
    @FocusState private var focused: Bool

    var body: some View {
      OTPField(code: $model.code, fieldState: $model.state, isFocused: $focused) { _ in .stop }
        .padding()
    }
  }
}

#endif
