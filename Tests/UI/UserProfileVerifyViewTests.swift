#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct UserProfileVerifyViewTests {
  @Test
  func readdedEmailAddressGetsItsOwnFirstCode() {
    var removed = EmailAddress.mock
    removed.id = "idn_removed"
    var readded = EmailAddress.mock
    readded.id = "idn_readded"
    let limiter = CodeLimiter(startTicking: { _ in {} })

    limiter.recordCodeSent(for: UserProfileVerifyView.codeLimiterIdentifier(for: .email(removed)))

    #expect(!limiter.isFirstRequest(for: UserProfileVerifyView.codeLimiterIdentifier(for: .email(removed))))
    #expect(limiter.isFirstRequest(for: UserProfileVerifyView.codeLimiterIdentifier(for: .email(readded))))
  }

  @Test
  func readdedPhoneNumberGetsItsOwnFirstCode() {
    var removed = PhoneNumber.mock
    removed.id = "idn_removed"
    var readded = PhoneNumber.mock
    readded.id = "idn_readded"
    let limiter = CodeLimiter(startTicking: { _ in {} })

    limiter.recordCodeSent(for: UserProfileVerifyView.codeLimiterIdentifier(for: .phone(removed)))

    #expect(!limiter.isFirstRequest(for: UserProfileVerifyView.codeLimiterIdentifier(for: .phone(removed))))
    #expect(limiter.isFirstRequest(for: UserProfileVerifyView.codeLimiterIdentifier(for: .phone(readded))))
  }
}

#endif
