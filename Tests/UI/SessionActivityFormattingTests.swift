#if os(iOS)

import ClerkKit
@testable import ClerkKitUI
import Testing

struct SessionActivityFormattingTests {
  @Test(arguments: [
    (ipAddress: "192.0.2.1", city: "Paris", country: "FR", expected: "192.0.2.1 (Paris, FR)"),
    (ipAddress: "192.0.2.1", city: nil, country: "FR", expected: "192.0.2.1 (FR)"),
    (ipAddress: "192.0.2.1", city: nil, country: nil, expected: "192.0.2.1"),
    (ipAddress: "", city: nil, country: nil, expected: ""),
    (ipAddress: nil, city: nil, country: nil, expected: ""),
  ] as [(ipAddress: String?, city: String?, country: String?, expected: String)])
  func ipAndLocationShowsParenthesesOnlyAroundAKnownLocation(
    ipAddress: String?,
    city: String?,
    country: String?,
    expected: String
  ) {
    let activity = SessionActivity(id: "sess_activity", ipAddress: ipAddress, city: city, country: country)

    #expect(activity.ipAndLocationFormatted == expected)
  }
}

#endif
