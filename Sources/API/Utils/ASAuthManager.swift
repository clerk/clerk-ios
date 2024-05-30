//
//  ASAuthManager.swift
//
//
//  Created by Mike Pitre on 5/28/24.
//


#if canImport(AuthenticationServices) && !os(watchOS)

import Foundation
import AuthenticationServices

@MainActor
final class ASAuthManager: NSObject {
    
    enum AuthType {
        case signInWithApple
    }
    
    let authType: AuthType
    
    init(authType: AuthType) {
        self.authType = authType
    }
    
    private var continuation: CheckedContinuation<ASAuthorization,Error>?
    
    func start() async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            switch authType {
                
            case .signInWithApple:
                
                let appleIDProvider = ASAuthorizationAppleIDProvider()
                let appleRequest = appleIDProvider.createRequest()
                appleRequest.requestedScopes = [.fullName, .email]
                let authorizationController = ASAuthorizationController(authorizationRequests: [appleRequest])
                authorizationController.delegate = self
                authorizationController.presentationContextProvider = self
                authorizationController.performRequests()
            }
        }
    }
}

extension ASAuthManager: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
        
        switch authorization.credential {
            
        case let appleIdCredential as ASAuthorizationAppleIDCredential:
            
            dump(appleIdCredential)
            
        default:
            break
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        continuation?.resume(throwing: error)
    }
    
}

extension ASAuthManager: ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
    
}

#endif
