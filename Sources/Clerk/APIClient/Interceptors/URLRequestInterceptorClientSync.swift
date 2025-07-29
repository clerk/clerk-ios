//
//  ClientSyncingMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/31/25.
//

import Foundation
import RequestBuilder

final class URLRequestInterceptorClientSync: URLRequestInterceptor, @unchecked Sendable {

    var parent: URLSessionManager!

    func data(for request: URLRequest) async throws -> (Data?, HTTPURLResponse?) {
        let (data, response) = try await parent.data(for: request)
        if let data, let client = decodeClient(from: data) {
            Task { @MainActor in
                Clerk.shared.client = client
            }
        }
        return (data, response)
    }

    private func decodeClient(from jsonData: Data) -> Client? {
        struct ClientWrapper: Decodable {
            let client: Client?

            enum CodingKeys: String, CodingKey {
                case response, client
            }

            init(from decoder: Decoder) throws {
                let container = try? decoder.container(keyedBy: CodingKeys.self)

                if let responseClient = try? container?.decode(Client.self, forKey: .response) {
                    self.client = responseClient
                    return
                }

                if let clientClient = try? container?.decode(Client.self, forKey: .client) {
                    self.client = clientClient
                    return
                }

                // If `Client` is the top-level object, attempt direct decoding (least common)
                if let topLevelClient = try? Client(from: decoder) {
                    self.client = topLevelClient
                    return
                }

                self.client = nil
            }
        }

        return (try? JSONDecoder.clerkDecoder.decode(ClientWrapper.self, from: jsonData))?.client
    }

}
