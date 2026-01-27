import Foundation
import Testing

@testable import ClerkKit

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
  func customResponseMiddlewareRunsFirst() throws {
    let recorder = OrderRecorder()
    let builtIn = RecordingResponseMiddleware(name: "builtIn", recorder: recorder)
    let custom = RecordingResponseMiddleware(name: "custom", recorder: recorder)

    let pipeline = NetworkingPipeline(responseMiddleware: [builtIn])
      .appendingResponseMiddleware([custom])

    let request = URLRequest(url: URL(string: "https://example.com")!)
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    try pipeline.validate(response, data: Data(), for: request)

    #expect(recorder.snapshot() == ["custom", "builtIn"])
  }
}
