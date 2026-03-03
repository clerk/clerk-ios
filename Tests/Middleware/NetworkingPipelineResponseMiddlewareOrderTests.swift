@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct NetworkingPipelineResponseMiddlewareOrderTests {
  private final class OrderRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func record(_ value: String) {
      lock.lock()
      values.append(value)
      lock.unlock()
    }

    func snapshot() -> [String] {
      lock.lock()
      let snapshot = values
      lock.unlock()
      return snapshot
    }
  }

  private struct RecordingResponseMiddleware: ClerkResponseMiddleware {
    let name: String
    let recorder: OrderRecorder

    func validate(_: HTTPURLResponse, data _: Data, for _: URLRequest) throws {
      recorder.record(name)
    }
  }

  @Test
  func customResponseMiddlewareRunsFirst() async throws {
    let recorder = OrderRecorder()
    let builtIn = RecordingResponseMiddleware(name: "builtIn", recorder: recorder)
    let custom = RecordingResponseMiddleware(name: "custom", recorder: recorder)

    let pipeline = NetworkingPipeline(responseMiddleware: [builtIn])
      .appendingResponseMiddleware([custom])

    let url = try #require(URL(string: "https://example.com"))
    let request = URLRequest(url: url)
    let requestURL = try #require(request.url)
    let response = try #require(HTTPURLResponse(
      url: requestURL,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))

    try await pipeline.validate(response, data: Data(), for: request)

    #expect(recorder.snapshot() == ["custom", "builtIn"])
  }
}
