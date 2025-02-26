//
//  UserService.swift
//  Clerk
//
//  Created by Mike Pitre on 2/25/25.
//

import AuthenticationServices
import Factory
import Foundation

struct UserService {
  var update: @MainActor (_ params: User.UpdateParams) async throws -> User
  var createEmailAddress: @MainActor (_ email: String) async throws -> EmailAddress
  var createPhoneNumber: @MainActor (_ phoneNumber: String) async throws -> PhoneNumber
  var createExternalAccountOAuth: @MainActor (_ provider: OAuthProvider, _ additionalScopes: [String]?) async throws -> ExternalAccount
  var createExternalAccountIDToken: @MainActor (_ provider: IDTokenProvider, _ idToken: String) async throws -> ExternalAccount
  var createPasskey: @MainActor () async throws -> Passkey
  var createTOTP: @MainActor () async throws -> TOTPResource
  var verifyTOTP: @MainActor (_ code: String) async throws -> TOTPResource
  var disableTOTP: @MainActor () async throws -> DeletedObject
  var getSessions: @MainActor (_ userId: String) async throws -> [Session]
  var updatePassword: @MainActor (_ params: User.UpdatePasswordParams) async throws -> User
  var setProfileImage: @MainActor (_ imageData: Data) async throws -> ImageResource
  var deleteProfileImage: @MainActor () async throws -> DeletedObject
  var delete: @MainActor () async throws -> DeletedObject
}

extension UserService {
  
  static var liveValue: UserService {
    .init(
      update: { params in
        let request = ClerkFAPI.v1.me.update(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          body: params
        )
        return try await Clerk.shared.apiClient.send(request).value.response
      },
      createEmailAddress: { email in
        let request = ClerkFAPI.v1.me.emailAddresses.post(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          body: ["email_address": email]
        )
        return try await Clerk.shared.apiClient.send(request).value.response
      },
      createPhoneNumber: { phoneNumber in
        let request = ClerkFAPI.v1.me.phoneNumbers.post(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          body: ["phone_number": phoneNumber]
        )
        return try await Clerk.shared.apiClient.send(request).value.response
      },
      createExternalAccountOAuth: { provider, additionalScopes in
        let request = ClerkFAPI.v1.me.externalAccounts.create(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          body: [
            "strategy": provider.strategy,
            "redirect_url": Clerk.shared.redirectConfig.redirectUrl,
            "additional_scopes": additionalScopes?.joined(separator: ",")
          ]
        )
        return try await Clerk.shared.apiClient.send(request).value.response
      },
      createExternalAccountIDToken: { provider, idToken in
        let request = ClerkFAPI.v1.me.externalAccounts.create(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          body: [
            "strategy": provider.strategy,
            "token": idToken
          ]
        )
        return try await Clerk.shared.apiClient.send(request).value.response
      },
      createPasskey: {
        let passkey = try await Passkey.create()
        
        guard let challenge = passkey.challenge else {
          throw ClerkClientError(message: "Unable to get the challenge for the passkey.")
        }
        
        guard let name = passkey.username else {
          throw ClerkClientError(message: "Unable to get the username for the passkey.")
        }
        
        guard let userId = passkey.userId else {
          throw ClerkClientError(message: "Unable to get the user ID for the passkey.")
        }
        
        let manager = PasskeyHelper()
        let authorization = try await manager.createPasskey(
          challenge: challenge,
          name: name,
          userId: userId
        )
        
        guard
          let credentialRegistration = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration,
          let rawAttestationObject = credentialRegistration.rawAttestationObject
        else {
          throw ClerkClientError(message: "Invalid credential type.")
        }
        
        let publicKeyCredential: [String: any Encodable] = [
          "id": credentialRegistration.credentialID.base64EncodedString().base64URLFromBase64String(),
          "rawId": credentialRegistration.credentialID.base64EncodedString().base64URLFromBase64String(),
          "type": "public-key",
          "response": [
            "attestationObject": rawAttestationObject.base64EncodedString().base64URLFromBase64String(),
            "clientDataJSON": credentialRegistration.rawClientDataJSON.base64EncodedString().base64URLFromBase64String()
          ]
        ]
        
        let publicKeyCredentialJSON = try JSON(publicKeyCredential)
        
        return try await passkey.attemptVerification(credential: publicKeyCredentialJSON.debugDescription)
      },
      createTOTP: {
        let request = ClerkFAPI.v1.me.totp.post(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        return try await Clerk.shared.apiClient.send(request).value.response
      },
      verifyTOTP: { code in
        let request = ClerkFAPI.v1.me.totp.attemptVerification.post(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          body: ["code": code]
        )
        return try await Clerk.shared.apiClient.send(request).value.response
      },
      disableTOTP: {
        let request = ClerkFAPI.v1.me.totp.delete(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        return try await Clerk.shared.apiClient.send(request).value.response
      },
      getSessions: { userId in
        let request = ClerkFAPI.v1.me.sessions.active.get(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let sessions = try await Clerk.shared.apiClient.send(request).value
        Clerk.shared.sessionsByUserId[userId] = sessions
        return sessions
      },
      updatePassword: { params in
        let request = ClerkFAPI.v1.me.changePassword.post(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          body: params
        )
        return try await Clerk.shared.apiClient.send(request).value.response
      },
      setProfileImage: { imageData in
        let boundary = UUID().uuidString
        var data = Data()
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        data.append(imageData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        let request = ClerkFAPI.v1.me.profileImage.post(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
          headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
        )
        return try await Clerk.shared.apiClient.upload(for: request, from: data).value.response
      },
      deleteProfileImage: {
        let request = ClerkFAPI.v1.me.profileImage.delete(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        return try await Clerk.shared.apiClient.send(request).value.response
      },
      delete: {
        let request = ClerkFAPI.v1.me.delete(
          queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        return try await Clerk.shared.apiClient.send(request).value.response
      }
    )
  }
  
}

extension Container {
  
  var userService: Factory<UserService> {
    self { .liveValue }
  }
  
}
