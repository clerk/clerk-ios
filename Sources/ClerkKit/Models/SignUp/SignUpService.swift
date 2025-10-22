//
//  SignUpService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import AuthenticationServices
import FactoryKit
import Foundation
import Get

extension Container {

    var signUpService: Factory<SignUpService> {
        self { SignUpService() }
    }

}

struct SignUpService {

    var create: @MainActor (_ strategy: SignUp.CreateStrategy, _ legalAccepted: Bool?, _ locale: String?) async throws -> SignUp = { strategy, legalAccepted, locale in
        var params = strategy.params
        params.legalAccepted = legalAccepted
        params.locale = locale ?? LocaleUtils.userLocale()

        let request = Request<ClientResponse<SignUp>>.init(
            path: "/v1/client/sign_ups",
            method: .post,
            body: params
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var createWithParams: @MainActor (_ params: any Encodable & Sendable) async throws -> SignUp = { params in
        var body: any Encodable & Sendable = params
        if var json = try? JSON(encodable: params), case .object(var object) = json {
            if object["locale"] == nil || object["locale"] == .null {
                object["locale"] = .string(LocaleUtils.userLocale())
                json = .object(object)
            }
            body = json
        }

        let request = Request<ClientResponse<SignUp>>.init(
            path: "/v1/client/sign_ups",
            method: .post,
            body: body
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var update: @MainActor (_ signUpId: String, _ params: SignUp.UpdateParams) async throws -> SignUp = { signUpId, params in
        let request = Request<ClientResponse<SignUp>>.init(
            path: "/v1/client/sign_ups/\(signUpId)",
            method: .patch,
            body: params
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var prepareVerification: @MainActor (_ signUpId: String, _ strategy: SignUp.PrepareStrategy) async throws -> SignUp = { signUpId, strategy in
        let request = Request<ClientResponse<SignUp>>.init(
            path: "/v1/client/sign_ups/\(signUpId)/prepare_verification",
            method: .post,
            body: strategy.params
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var attemptVerification: @MainActor (_ signUpId: String, _ strategy: SignUp.AttemptStrategy) async throws -> SignUp = { signUpId, strategy in
        let request = Request<ClientResponse<SignUp>>.init(
            path: "/v1/client/sign_ups/\(signUpId)/attempt_verification",
            method: .post,
            body: strategy.params
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var get: @MainActor (_ signUpId: String, _ rotatingTokenNonce: String?) async throws -> SignUp = { signUpId, rotatingTokenNonce in
        var queryParams: [(String, String?)] = []
        if let rotatingTokenNonce {
            queryParams.append((
                "rotating_token_nonce",
                value: rotatingTokenNonce.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            ))
        }

        let request = Request<ClientResponse<SignUp>>.init(
            path: "/v1/client/sign_ups/\(signUpId)",
            method: .get,
            query: queryParams
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    #if !os(tvOS) && !os(watchOS)
    var authenticateWithRedirectStatic: @MainActor (_ strategy: SignUp.AuthenticateWithRedirectStrategy, _ prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult = { strategy, prefersEphemeralWebBrowserSession in
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

    var authenticateWithRedirect: @MainActor (_ signUp: SignUp, _ prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult = { signUp, prefersEphemeralWebBrowserSession in
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

    var authenticateWithIdTokenStatic: @MainActor (_ provider: IDTokenProvider, _ idToken: String) async throws -> TransferFlowResult = { provider, idToken in
        let signUp = try await SignUp.create(strategy: .idToken(provider: provider, idToken: idToken))
        return try await signUp.handleTransferFlow()
    }

    var authenticateWithIdToken: @MainActor (_ signUp: SignUp) async throws -> TransferFlowResult = { signUp in
        try await signUp.handleTransferFlow()
    }

}
