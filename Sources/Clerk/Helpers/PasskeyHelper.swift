//
//  PasskeyManager.swift
//
//
//  Created by Mike Pitre on 9/5/24.
//

#if canImport(AuthenticationServices) && !os(watchOS)

import Foundation
import AuthenticationServices
import os

final class PasskeyHelper: NSObject {

    @MainActor
    public static var controller: ASAuthorizationController?

    @MainActor
    var domain: String {
        guard let urlComponents = URLComponents(string: Clerk.shared.frontendApiUrl) else {
            return ""
        }

        let host = urlComponents.host ?? ""
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    @MainActor
    func signIn(challenge: Data, preferImmediatelyAvailableCredentials: Bool) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)

            let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)

            // Pass in any mix of supported sign-in request types.
            let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
            authController.delegate = self
            authController.presentationContextProvider = self
            Self.controller = authController

            #if !os(tvOS)

            if preferImmediatelyAvailableCredentials {
                // If credentials are available, presents a modal sign-in sheet.
                // If there are no locally saved credentials, no UI appears and
                // the system passes ASAuthorizationError.Code.canceled to call
                // `AccountManager.authorizationController(controller:didCompleteWithError:)`.
                authController.performRequests(options: .preferImmediatelyAvailableCredentials)
            } else {
                // If credentials are available, presents a modal sign-in sheet.
                // If there are no locally saved credentials, the system presents a QR code to allow signing in with a
                // passkey from a nearby device.
                authController.performRequests()
            }

            #else

            authController.performRequests()

            #endif
        }
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    @MainActor
    func beginAutoFillAssistedPasskeySignIn(challenge: Data) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)

            let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)

            // AutoFill-assisted requests only support ASAuthorizationPlatformPublicKeyCredentialAssertionRequest.
            let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
            authController.delegate = self
            authController.presentationContextProvider = self
            Self.controller = authController

            authController.performAutoFillAssistedRequests()
        }
    }
    #endif

    @MainActor
    func createPasskey(challenge: Data, name: String, userId: Data) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)

            let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(
                challenge: challenge,
                name: name,
                userID: userId
            )

            // Use only ASAuthorizationPlatformPublicKeyCredentialRegistrationRequests or
            // ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequests here.
            let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
            authController.delegate = self
            authController.presentationContextProvider = self
            Self.controller = authController

            authController.performRequests()
        }
    }

}

extension PasskeyHelper: ASAuthorizationControllerDelegate {

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let logger = Logger()
        switch authorization.credential {
        case let credentialRegistration as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            logger.log("A new passkey was registered: \(credentialRegistration)")
            // Verify the attestationObject and clientDataJSON with your service.
            // The attestationObject contains the user's new public key to store and use for subsequent sign-ins.
            // let attestationObject = credentialRegistration.rawAttestationObject
            // let clientDataJSON = credentialRegistration.rawClientDataJSON

            // After the server verifies the registration and creates the user account, sign in the user with the new account.
            continuation?.resume(returning: authorization)
        case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            logger.log("A passkey was used to sign in: \(credentialAssertion)")
            // Verify the below signature and clientDataJSON with your service for the given userID.
            // let signature = credentialAssertion.signature
            // let clientDataJSON = credentialAssertion.rawClientDataJSON
            // let userID = credentialAssertion.userID

            // After the server verifies the assertion, sign in the user.
            continuation?.resume(returning: authorization)
        case let passwordCredential as ASPasswordCredential:
            logger.log("A password was provided: \(passwordCredential)")
            // Verify the userName and password with your service.
            // let userName = passwordCredential.user
            // let password = passwordCredential.password

            // After the server verifies the userName and password, sign in the user.
            continuation?.resume(returning: authorization)
        default:
            fatalError("Received unknown authorization type.")
        }

    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        continuation?.resume(throwing: error)
    }

}

extension PasskeyHelper: ASAuthorizationControllerPresentationContextProviding {
    @MainActor
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(iOS)
        UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
        #else
        ASPresentationAnchor()
        #endif
    }
}

#endif
