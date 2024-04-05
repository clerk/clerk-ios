//
//  PersistenceManager.swift
//
//
//  Created by Mike Pitre on 3/27/24.
//

import Foundation

struct PersistenceManager {
    
    private static func clientDataURL() throws -> URL {
        try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        .appendingPathComponent("client.data")
    }
    
    private static func environmentDataURL() throws -> URL {
        try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        .appendingPathComponent("environment.data")
    }
    
    static func loadClient() async throws -> Client? {
        let task = Task<Client?, Error> {
            let fileURL = try clientDataURL()
            guard let data = try? Data(contentsOf: fileURL) else {
                return nil
            }
            let client = try JSONDecoder.clerkDecoder.decode(Client.self, from: data)
            return client
        }
        let client = try await task.value
        return client
    }
    
    static func loadEnvironment() async throws -> Clerk.Environment? {
        let task = Task<Clerk.Environment?, Error> {
            let fileURL = try environmentDataURL()
            guard let data = try? Data(contentsOf: fileURL) else {
                return nil
            }
            let environment = try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: data)
            return environment
        }
        let environment = try await task.value
        return environment
    }
    
    static func saveClient(_ client: Client) async throws {
        let task = Task {
            let data = try JSONEncoder.clerkEncoder.encode(client)
            let outfile = try clientDataURL()
            try data.write(to: outfile, options: .completeFileProtection)
        }
        _ = try await task.value
    }
    
    static func saveEnvironment(_ environment: Clerk.Environment) async throws {
        let task = Task {
            let data = try JSONEncoder.clerkEncoder.encode(environment)
            let outfile = try environmentDataURL()
            try data.write(to: outfile, options: .completeFileProtection)
        }
        _ = try await task.value
    }
    
    static func deleteClientData() async throws {
        let task = Task {
            try FileManager.default.removeItem(at: clientDataURL())
        }
        _ = try await task.value
    }
    
    static func deleteEnvironmentData() async throws {
        let task = Task {
            try FileManager.default.removeItem(at: environmentDataURL())
        }
        _ = try await task.value
    }
    
}
