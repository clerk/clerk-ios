//
//  ASAuth.swift
//
//
//  Created by Mike Pitre on 5/28/24.
//


#if canImport(AuthenticationServices) && !os(watchOS)

import Foundation
import AuthenticationServices

final public class SignInWithAppleHelper: NSObject {
    
    private var continuation: CheckedContinuation<ASAuthorization,Error>?
    
    @MainActor
    func start(requestedScopes: [ASAuthorization.Scope]) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
                                            
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let appleRequest = appleIDProvider.createRequest()
            appleRequest.requestedScopes = requestedScopes
            appleRequest.nonce = UUID().uuidString
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [appleRequest])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }
    
    /// Presents the native sign in with apple sheet to get an ASAuthorizationAppleIDCredential
    @MainActor
    public func getAppleIdCredential(requestedScopes: [ASAuthorization.Scope] = [.email]) async throws -> ASAuthorizationAppleIDCredential {
        let authManager = SignInWithAppleHelper()
        let authorization = try await authManager.start(requestedScopes: requestedScopes)
        
        guard let appleIdCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw ClerkClientError(message: "Unable to get your Apple ID credential.")
        }
        
        return appleIdCredential
    }
    
}

extension SignInWithAppleHelper: ASAuthorizationControllerDelegate {
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        continuation?.resume(throwing: error)
    }
    
}

extension SignInWithAppleHelper: ASAuthorizationControllerPresentationContextProviding {
    
    @MainActor
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
    
}

#endif
