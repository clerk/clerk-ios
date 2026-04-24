import Foundation

func clerkPaginationOffset(forPage page: Int, pageSize: Int) -> Int {
  max(page - 1, 0) * pageSize
}

func clerkExternalAuthenticationURL(from redirectUrl: String?) throws -> URL {
  guard let redirectUrl,
        let url = URL(string: redirectUrl)
  else {
    throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
  }

  return url
}

func clerkPasskeyCredentialJSONString(from jsonObject: Any) throws -> String {
  let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
  guard let credential = String(data: jsonData, encoding: .utf8) else {
    throw ClerkClientError(message: "Unable to encode the passkey credential.")
  }

  return credential
}
