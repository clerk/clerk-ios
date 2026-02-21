//
//  CodeVerificationStatusView.swift
//  Clerk
//

#if os(iOS)

import SwiftUI

enum CodeVerificationState {
  case `default`
  case verifying
  case success
  case error(Error)

  var showResend: Bool {
    switch self {
    case .default, .error:
      true
    case .verifying, .success:
      false
    }
  }
}

struct CodeVerificationStatusView: View {
  @Environment(\.clerkTheme) private var theme

  let state: CodeVerificationState

  var body: some View {
    Group {
      switch state {
      case .verifying:
        HStack(spacing: 4) {
          SpinnerView()
            .frame(width: 16, height: 16)
          Text("Verifying...", bundle: .module)
        }
        .foregroundStyle(theme.colors.mutedForeground)
      case .success:
        HStack(spacing: 4) {
          Image("icon-check-circle", bundle: .module)
            .foregroundStyle(theme.colors.success)
          Text("Success", bundle: .module)
            .foregroundStyle(theme.colors.mutedForeground)
        }
      case let .error(error):
        ErrorText(error: error)
      default:
        EmptyView()
      }
    }
    .font(theme.fonts.subheadline)
  }
}

#endif
