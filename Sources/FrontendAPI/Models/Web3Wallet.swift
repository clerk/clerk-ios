//
//  Web3Wallet.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct Web3Wallet: Codable {
    public let id: String
    public let web3Wallet: String
    public let verification: Verification
}
