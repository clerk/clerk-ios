//
//  SwiftUIView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/13/25.
//

#if os(iOS)

  import SwiftUI

  struct SignInFactorTwoView: View {
    @Environment(\.clerkTheme) private var theme

    let factor: Factor

    @ViewBuilder
    var viewForFactor: some View {
      switch factor.strategy {
      case "totp":
        Text(verbatim: "totp")
      case "sms":
        Text(verbatim: "sms")
      case "backup_code":
        Text(verbatim: "backup code")
      default:
        SignInGetHelpView()
      }
    }

    var body: some View {
      viewForFactor
        .background(theme.colors.background)
    }
  }

  #Preview {
    SignInFactorOneView(
      factor: .init(
        strategy: "totp"
      )
    )
  }

#endif
