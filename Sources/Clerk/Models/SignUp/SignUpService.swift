//
//  SignUpService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import AuthenticationServices
import FactoryKit
import Foundation

extension Container {

    var signUpService: Factory<SignUpService> {
        self { @MainActor in SignUpService() }
    }

}

@MainActor
struct SignUpService {

    var create: (_ strategy: SignUp.CreateStrategy, _ legalAccepted: Bool?) async throws -> SignUp = { @MainActor strategy, legalAccepted in
        var params = strategy.params
        params.legalAccepted = legalAccepted

        return try await Container.shared.apiClient().request()
            .add(path: "/v1/client/sign_ups")
            .method(.post)
            .body(formEncode: params)
            .data(type: ClientResponse<SignUp>.self)
            .async()
            .response
    }

    var createWithParams: (_ params: any Encodable & Sendable) async throws -> SignUp = { params in
        try await Container.shared.apiClient().request()
            .add(path: "/v1/client/sign_ups")
            .method(.post)
            .body(formEncode: params)
            .data(type: ClientResponse<SignUp>.self)
            .async()
            .response
    }

    var update: (_ signUpId: String, _ params: SignUp.UpdateParams) async throws -> SignUp = { signUpId, params in
        try await Container.shared.apiClient().request()
            .add(path: "/v1/client/sign_ups/\(signUpId)")
            .method(.patch)
            .body(formEncode: params)
            .data(type: ClientResponse<SignUp>.self)
            .async()
            .response
    }

    var prepareVerification: (_ signUpId: String, _ strategy: SignUp.PrepareStrategy) async throws -> SignUp = { signUpId, strategy in
        try await Container.shared.apiClient().request()
            .add(path: "/v1/client/sign_ups/\(signUpId)/prepare_verification")
            .method(.post)
            .body(formEncode: strategy.params)
            .data(type: ClientResponse<SignUp>.self)
            .async()
            .response
    }

    var attemptVerification: (_ signUpId: String, _ strategy: SignUp.AttemptStrategy) async throws -> SignUp = { signUpId, strategy in
        try await Container.shared.apiClient().request()
            .add(path: "/v1/client/sign_ups/\(signUpId)/attempt_verification")
            .method(.post)
            .body(formEncode: strategy.params)
            .data(type: ClientResponse<SignUp>.self)
            .async()
            .response
    }

    var get: (_ signUpId: String, _ rotatingTokenNonce: String?) async throws -> SignUp = { signUpId, rotatingTokenNonce in
        var queryItems: [URLQueryItem] = []
        if let rotatingTokenNonce {
            queryItems.append(
                .init(
                    name: "rotating_token_nonce",
                    value: rotatingTokenNonce.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                )
            )
        }

        return try await Container.shared.apiClient().request()
            .add(path: "/v1/client/sign_ups/\(signUpId)")
            .add(queryItems: queryItems)
            .data(type: ClientResponse<SignUp>.self)
            .async()
            .response
    }

    #if !os(tvOS) && !os(watchOS)
    var authenticateWithRedirectStatic: (_ strategy: SignUp.AuthenticateWithRedirectStrategy, _ prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult = { strategy, prefersEphemeralWebBrowserSession in
        let signUp = try await SignUp.create(strategy: strategy.signUpStrategy)

        guard
            let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
            let redirectUrl = verification.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }

        let authSession = WebAuthentication(
            url: url,
            prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
        )

        let callbackUrl = try await authSession.start()
        let transferFlowResult = try await signUp.handleOAuthCallbackUrl(callbackUrl)
        return transferFlowResult
    }

    var authenticateWithRedirect: (_ signUp: SignUp, _ prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult = { signUp, prefersEphemeralWebBrowserSession in
        guard
            let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
            let redirectUrl = verification.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }

        let authSession = WebAuthentication(
            url: url,
            prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
        )

        let callbackUrl = try await authSession.start()
        let transferFlowResult = try await signUp.handleOAuthCallbackUrl(callbackUrl)
        return transferFlowResult
    }
    #endif

    var authenticateWithIdTokenStatic: (_ provider: IDTokenProvider, _ idToken: String) async throws -> TransferFlowResult = { provider, idToken in
        let signUp = try await SignUp.create(strategy: .idToken(provider: provider, idToken: idToken))
        return try await signUp.handleTransferFlow()
    }

    var authenticateWithIdToken: (_ signUp: SignUp) async throws -> TransferFlowResult = { signUp in
        try await signUp.handleTransferFlow()
    }

}
