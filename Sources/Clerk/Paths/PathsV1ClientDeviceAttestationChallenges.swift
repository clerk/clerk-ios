//
//  PathsV1ClientDeviceAttestationChallenges.swift
//  Clerk
//
//  Created by Mike Pitre on 1/29/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.ClientEndpoint.DeviceAttestationEndpoint {

  var challenges: ChallengesEndpoint {
    ChallengesEndpoint(path: path + "/challenges")
  }

  struct ChallengesEndpoint {
    /// Path: `v1/client/device_attestation/challenges`
    let path: String

    var post: Request<[String: String]> {
      .init(path: path, method: .post)
    }
  }

}
