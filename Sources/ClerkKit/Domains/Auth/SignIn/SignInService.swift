//
//  SignInService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import AuthenticationServices
import FactoryKit
import Foundation

extension Container {

    var signInService: Factory<SignInServiceProtocol> {
        self { SignInService() }
    }

}

protocol SignInServiceProtocol: Sendable {
    @MainActor func create(strategy: SignIn.CreateStrategy, locale: String?) async throws -> SignIn
    @MainActor func createWithParams(params: any Encodable & Sendable) async throws -> SignIn
    @MainActor func resetPassword(signInId: String, params: SignIn.ResetPasswordParams) async throws -> SignIn
    @MainActor func prepareFirstFactor(signInId: String, strategy: SignIn.PrepareFirstFactorStrategy, signIn: SignIn) async throws -> SignIn
    @MainActor func attemptFirstFactor(signInId: String, strategy: SignIn.AttemptFirstFactorStrategy) async throws -> SignIn
    @MainActor func prepareSecondFactor(signInId: String, strategy: SignIn.PrepareSecondFactorStrategy, signIn: SignIn) async throws -> SignIn
    @MainActor func attemptSecondFactor(signInId: String, strategy: SignIn.AttemptSecondFactorStrategy) async throws -> SignIn
    @MainActor func get(signInId: String, rotatingTokenNonce: String?) async throws -> SignIn

    #if !os(tvOS) && !os(watchOS)
    @MainActor func authenticateWithRedirectStatic(strategy: SignIn.AuthenticateWithRedirectStrategy, prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult
    @MainActor func authenticateWithRedirect(signIn: SignIn, prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult
    #endif

    #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
    @MainActor func getCredentialForPasskey(signIn: SignIn, autofill: Bool, preferImmediatelyAvailableCredentials: Bool) async throws -> String
    @MainActor func authenticateWithIdTokenStatic(provider: IDTokenProvider, idToken: String) async throws -> TransferFlowResult
    @MainActor func authenticateWithIdToken(signIn: SignIn) async throws -> TransferFlowResult
    #endif
}

final class SignInService: SignInServiceProtocol {

    private var apiClient: APIClient { Container.shared.apiClient() }

    @MainActor
    func create(strategy: SignIn.CreateStrategy, locale: String?) async throws -> SignIn {
        var params = strategy.params
        params.locale = locale ?? LocaleUtils.userLocale()

        let request = Request<ClientResponse<SignIn>>(
            path: "/v1/client/sign_ins",
            method: .post,
            body: params
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func createWithParams(params: any Encodable & Sendable) async throws -> SignIn {
        var body: any Encodable & Sendable = params
        if var json = try? JSON(encodable: params), case .object(var object) = json {
            if object["locale"] == nil || object["locale"] == .null {
                object["locale"] = .string(LocaleUtils.userLocale())
                json = .object(object)
            }
            body = json
        }

        let request = Request<ClientResponse<SignIn>>(
            path: "/v1/client/sign_ins",
            method: .post,
            body: body
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func resetPassword(signInId: String, params: SignIn.ResetPasswordParams) async throws -> SignIn {
        let request = Request<ClientResponse<SignIn>>(
            path: "/v1/client/sign_ins/\(signInId)/reset_password",
            method: .post,
            body: params
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func prepareFirstFactor(signInId: String, strategy: SignIn.PrepareFirstFactorStrategy, signIn: SignIn) async throws -> SignIn {
        let request = Request<ClientResponse<SignIn>>(
            path: "/v1/client/sign_ins/\(signInId)/prepare_first_factor",
            method: .post,
            body: strategy.params(signIn: signIn)
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func attemptFirstFactor(signInId: String, strategy: SignIn.AttemptFirstFactorStrategy) async throws -> SignIn {
        let request = Request<ClientResponse<SignIn>>(
            path: "/v1/client/sign_ins/\(signInId)/attempt_first_factor",
            method: .post,
            body: strategy.params
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func prepareSecondFactor(signInId: String, strategy: SignIn.PrepareSecondFactorStrategy, signIn: SignIn) async throws -> SignIn {
        let request = Request<ClientResponse<SignIn>>(
            path: "/v1/client/sign_ins/\(signInId)/prepare_second_factor",
            method: .post,
            body: strategy.params(signIn: signIn)
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func attemptSecondFactor(signInId: String, strategy: SignIn.AttemptSecondFactorStrategy) async throws -> SignIn {
        let request = Request<ClientResponse<SignIn>>(
            path: "/v1/client/sign_ins/\(signInId)/attempt_second_factor",
            method: .post,
            body: strategy.params
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func get(signInId: String, rotatingTokenNonce: String?) async throws -> SignIn {
        var queryParams: [(String, String?)] = []
        if let rotatingTokenNonce {
            queryParams.append((
                "rotating_token_nonce",
                rotatingTokenNonce.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            ))
        }

        let request = Request<ClientResponse<SignIn>>(
            path: "/v1/client/sign_ins/\(signInId)",
            method: .get,
            query: queryParams
        )

        return try await apiClient.send(request).value.response
    }

    #if !os(tvOS) && !os(watchOS)
    @MainActor
    func authenticateWithRedirectStatic(strategy: SignIn.AuthenticateWithRedirectStrategy, prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult {
        let signIn = try await SignIn.create(strategy: strategy.signInStrategy)

        guard let externalVerificationRedirectUrl = signIn.firstFactorVerification?.externalVerificationRedirectUrl,
              let url = URL(string: externalVerificationRedirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }

        let authSession = WebAuthentication(url: url, prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession)
        let callbackUrl = try await authSession.start()
        return try await signIn.handleOAuthCallbackUrl(callbackUrl)
    }

    @MainActor
    func authenticateWithRedirect(signIn: SignIn, prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult {
        guard let externalVerificationRedirectUrl = signIn.firstFactorVerification?.externalVerificationRedirectUrl,
              let url = URL(string: externalVerificationRedirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }

        let authSession = WebAuthentication(url: url, prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession)
        let callbackUrl = try await authSession.start()
        return try await signIn.handleOAuthCallbackUrl(callbackUrl)
    }
    #endif

    #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
    @MainActor
    func getCredentialForPasskey(signIn: SignIn, autofill: Bool, preferImmediatelyAvailableCredentials: Bool) async throws -> String {
        guard
            let nonceJSON = signIn.firstFactorVerification?.nonce?.toJSON(),
            let challengeString = nonceJSON["challenge"]?.stringValue,
            let challenge = challengeString.dataFromBase64URL()
        else {
            throw ClerkClientError(message: "Unable to get the challenge for the passkey.")
        }

        let manager = PasskeyHelper()
        let authorization: ASAuthorization

        #if os(iOS) && !targetEnvironment(macCatalyst)
        if autofill {
            authorization = try await manager.beginAutoFillAssistedPasskeySignIn(challenge: challenge)
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

    @MainActor
    func authenticateWithIdTokenStatic(provider: IDTokenProvider, idToken: String) async throws -> TransferFlowResult {
        let signIn = try await SignIn.create(strategy: .idToken(provider: provider, idToken: idToken))
        return try await signIn.handleTransferFlow()
    }

    @MainActor
    func authenticateWithIdToken(signIn: SignIn) async throws -> TransferFlowResult {
        try await signIn.handleTransferFlow()
    }
    #endif
}
