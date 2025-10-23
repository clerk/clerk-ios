//
//  SignInService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import AuthenticationServices
import FactoryKit
import Foundation
import Get

extension Container {

    var signInService: Factory<SignInService> {
        self { SignInService() }
    }

}

struct SignInService {

    var create: @MainActor (_ strategy: SignIn.CreateStrategy) async throws -> SignIn = { strategy in
        let request = Request<ClientResponse<SignIn>>.init(
            path: "/v1/client/sign_ins",
            method: .post,
            body: strategy.params
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var createWithParams: @MainActor (_ params: any Encodable & Sendable) async throws -> SignIn = { params in
        let request = Request<ClientResponse<SignIn>>.init(
            path: "/v1/client/sign_ins",
            method: .post,
            body: params
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var resetPassword: @MainActor (_ signInId: String, _ params: SignIn.ResetPasswordParams) async throws -> SignIn = { signInId, params in
        let request = Request<ClientResponse<SignIn>>.init(
            path: "/v1/client/sign_ins/\(signInId)/reset_password",
            method: .post,
            body: params
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var prepareFirstFactor: @MainActor (_ signInId: String, _ strategy: SignIn.PrepareFirstFactorStrategy, _ signIn: SignIn) async throws -> SignIn = { signInId, strategy, signIn in
        let request = Request<ClientResponse<SignIn>>.init(
            path: "/v1/client/sign_ins/\(signInId)/prepare_first_factor",
            method: .post,
            body: strategy.params(signIn: signIn)
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var attemptFirstFactor: @MainActor (_ signInId: String, _ strategy: SignIn.AttemptFirstFactorStrategy) async throws -> SignIn = { signInId, strategy in
        let request = Request<ClientResponse<SignIn>>.init(
            path: "/v1/client/sign_ins/\(signInId)/attempt_first_factor",
            method: .post,
            body: strategy.params
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var prepareSecondFactor: @MainActor (_ signInId: String, _ strategy: SignIn.PrepareSecondFactorStrategy) async throws -> SignIn = { signInId, strategy in
        let request = Request<ClientResponse<SignIn>>.init(
            path: "/v1/client/sign_ins/\(signInId)/prepare_second_factor",
            method: .post,
            body: strategy.params
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var attemptSecondFactor: @MainActor (_ signInId: String, _ strategy: SignIn.AttemptSecondFactorStrategy) async throws -> SignIn = { signInId, strategy in
        let request = Request<ClientResponse<SignIn>>.init(
            path: "/v1/client/sign_ins/\(signInId)/attempt_second_factor",
            method: .post,
            body: strategy.params
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var get: @MainActor (_ signInId: String, _ rotatingTokenNonce: String?) async throws -> SignIn = { signInId, rotatingTokenNonce in
        var queryParams: [(String, String?)] = []
        if let rotatingTokenNonce {
            queryParams.append((
                "rotating_token_nonce", 
                value: rotatingTokenNonce.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            ))
        }

        let request = Request<ClientResponse<SignIn>>.init(
            path: "/v1/client/sign_ins/\(signInId)",
            method: .get,
            query: queryParams
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    #if !os(tvOS) && !os(watchOS)
    var authenticateWithRedirectStatic: @MainActor (_ strategy: SignIn.AuthenticateWithRedirectStrategy, _ prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult = { strategy, prefersEphemeralWebBrowserSession in
        let signIn = try await SignIn.create(strategy: strategy.signInStrategy)

        guard let externalVerificationRedirectUrl = signIn.firstFactorVerification?.externalVerificationRedirectUrl, let url = URL(string: externalVerificationRedirectUrl) else {
            throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }

        let authSession = WebAuthentication(url: url, prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession)
        let callbackUrl = try await authSession.start()
        let transferFlowResult = try await signIn.handleOAuthCallbackUrl(callbackUrl)
        return transferFlowResult
    }

    var authenticateWithRedirect: @MainActor (_ signIn: SignIn, _ prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult = { signIn, prefersEphemeralWebBrowserSession in
        guard let externalVerificationRedirectUrl = signIn.firstFactorVerification?.externalVerificationRedirectUrl,
            let url = URL(string: externalVerificationRedirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }

        let authSession = WebAuthentication(url: url, prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession)
        let callbackUrl = try await authSession.start()
        let transferFlowResult = try await signIn.handleOAuthCallbackUrl(callbackUrl)
        return transferFlowResult
    }
    #endif

    #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
    var getCredentialForPasskey: @MainActor (_ signIn: SignIn, _ autofill: Bool, _ preferImmediatelyAvailableCredentials: Bool) async throws -> String = { signIn, autofill, preferImmediatelyAvailableCredentials in
        guard
            let nonceJSON = signIn.firstFactorVerification?.nonce?.toJSON(),
            let challengeString = nonceJSON["challenge"]?.stringValue,
            let challenge = challengeString.dataFromBase64URL()
        else {
            throw ClerkClientError(message: "Unable to get the challenge for the passkey.")
        }

        let manager = PasskeyHelper()
        var authorization: ASAuthorization

        #if os(iOS) && !targetEnvironment(macCatalyst)
        if autofill {
            authorization = try await manager.beginAutoFillAssistedPasskeySignIn(
                challenge: challenge
            )
        } else {
            authorization = try await manager.signIn(
                challenge: challenge,
                preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
            )
        }
        #else
        authorization = try await manager.signIn(
            challenge: challenge,
            preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
        )
        #endif

        guard
            let credentialAssertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion,
            let authenticatorData = credentialAssertion.rawAuthenticatorData
        else {
            throw ClerkClientError(message: "Invalid credential type.")
        }

        let publicKeyCredential: [String: any Encodable] = [
            "id": credentialAssertion.credentialID.base64EncodedString().base64URLFromBase64String(),
            "rawId": credentialAssertion.credentialID.base64EncodedString().base64URLFromBase64String(),
            "type": "public-key",
            "response": [
                "authenticatorData": authenticatorData.base64EncodedString().base64URLFromBase64String(),
                "clientDataJSON": credentialAssertion.rawClientDataJSON.base64EncodedString().base64URLFromBase64String(),
                "signature": credentialAssertion.signature.base64EncodedString().base64URLFromBase64String(),
                "userHandle": credentialAssertion.userID.base64EncodedString().base64URLFromBase64String()
            ]
        ]

        return try JSON(publicKeyCredential).debugDescription
    }
    #endif

    var authenticateWithIdTokenStatic: @MainActor (_ provider: IDTokenProvider, _ idToken: String) async throws -> TransferFlowResult = { provider, idToken in
        let signIn = try await SignIn.create(strategy: .idToken(provider: provider, idToken: idToken))
        return try await signIn.handleTransferFlow()
    }

    var authenticateWithIdToken: @MainActor (_ signIn: SignIn) async throws -> TransferFlowResult = { signIn in
        try await signIn.handleTransferFlow()
    }

}
