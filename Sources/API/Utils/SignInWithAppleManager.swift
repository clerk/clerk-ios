//
//  ASAuth.swift
//
//
//  Created by Mike Pitre on 5/28/24.
//


#if canImport(AuthenticationServices) && !os(watchOS)

import Foundation
import AuthenticationServices

final public class SignInWithAppleManager: NSObject {
    
    private var continuation: CheckedContinuation<ASAuthorization,Error>?
    
    @MainActor
    private var requestedScopes: [ASAuthorization.Scope]? {
        var scopes: [ASAuthorization.Scope]? = [.email]
        
        if Clerk.shared.environment?.userSettings.nameIsEnabled == true {
            scopes?.append(.fullName)
        }
        
        return scopes
    }
    
    @MainActor
    func start() async throws -> ASAuthorization {
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
    static public func getAppleIdCredential() async throws -> ASAuthorizationAppleIDCredential {
        let authManager = SignInWithAppleManager()
        let authorization = try await authManager.start()
        
        guard let appleIdCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw ClerkClientError(message: "Unable to get your Apple ID credential.")
        }
        
        return appleIdCredential
    }
    
}

extension SignInWithAppleManager: ASAuthorizationControllerDelegate {
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        continuation?.resume(throwing: error)
    }
    
}

extension SignInWithAppleManager: ASAuthorizationControllerPresentationContextProviding {
    
    @MainActor
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
    
}

#endif
