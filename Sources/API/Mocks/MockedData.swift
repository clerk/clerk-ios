//
//  MockedData.swift
//
//
//  Created by Mike Pitre on 2/9/24.
//

import Foundation

final class MockedData {
    static let clientJSON: URL = Bundle(for: MockedData.self).url(forResource: "Sources/API/Mocks/JSONFiles/Client", withExtension: "json")!
    static let environmentJSON: URL = Bundle(for: MockedData.self).url(forResource: "Sources/API/Mocks/JSONFiles/Environment", withExtension: "json")!
    static let sessionsJSON: URL = Bundle(for: MockedData.self).url(forResource: "Sources/API/Mocks/JSONFiles/Sessions", withExtension: "json")!
    static let userJSON: URL = Bundle(for: MockedData.self).url(forResource: "Sources/API/Mocks/JSONFiles/User", withExtension: "json")!
}

extension Clerk {
    
    public static var mock: Clerk {
        let clerk = Clerk()
        clerk.client = try! JSONDecoder().decode(Client.self, from: Data(contentsOf: MockedData.clientJSON))
        clerk.environment = try! JSONDecoder().decode(Environment.self, from: Data(contentsOf: MockedData.environmentJSON))
        let user = try! JSONDecoder().decode(User.self, from: Data(contentsOf: MockedData.userJSON))
        clerk.sessionsByUserId[user.id] = try! JSONDecoder().decode([Session].self, from: Data(contentsOf: MockedData.sessionsJSON))
        return clerk
    }
    
}
