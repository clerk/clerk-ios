#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import ConcurrencyExtras
import Foundation
import Nuke
import Testing

@MainActor
@Suite(.serialized)
struct ClerkImagePrefetchTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func prefetchedImagesFinishLoadingAfterTheCallReturns() async throws {
    let pipeline = ImagePipeline {
      $0.dataLoader = DelayedImageLoader()
      $0.imageCache = ImageCache()
      $0.dataCache = nil
    }
    let previousPrefetcher = Clerk.imagePrefetcher
    Clerk.imagePrefetcher = ImagePrefetcher(pipeline: pipeline)
    defer { Clerk.imagePrefetcher = previousPrefetcher }

    let logoUrl = try #require(URL(string: "https://img.clerk.com/prefetch-test-logo.png"))
    var environment = Clerk.Environment.mock
    environment.displayConfig.logoImageUrl = logoUrl.absoluteString
    let clerk = Clerk()
    clerk.environment = environment

    clerk.prefetchImages()

    for _ in 0 ..< 200 where pipeline.cache[logoUrl] == nil {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(pipeline.cache[logoUrl] != nil)
  }
}

private final class DelayedImageLoader: DataLoading {
  private static let png = Data(
    base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
  )!

  func loadData(
    with request: URLRequest,
    didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
    completion: @escaping @Sendable (Error?) -> Void
  ) -> any Cancellable {
    let task = DelayedLoadTask()
    DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(200)) {
      guard !task.isCancelled.value, let url = request.url,
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
      else { return }
      didReceiveData(Self.png, response)
      completion(nil)
    }
    return task
  }
}

private final class DelayedLoadTask: Cancellable {
  let isCancelled = LockIsolated(false)

  func cancel() {
    isCancelled.setValue(true)
  }
}

#endif
