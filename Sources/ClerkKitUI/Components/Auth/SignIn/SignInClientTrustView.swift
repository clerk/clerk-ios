//
//  SignInClientTrustView.swift
//  Clerk
//
//  Created by Tom Milewski on 12/15/25.
//

#if os(iOS)

import SwiftUI

struct SignInClientTrustView: View {
    let factor: Factor

    var body: some View {
        switch factor.strategy {
        case "phone_code", "email_code":
            SignInFactorCodeView(factor: factor, mode: .clientTrust)
        default:
            SignInGetHelpView()
        }
    }
}

#Preview {
    SignInClientTrustView(
        factor: .init(
            strategy: "email_code"
        )
    )
}

#endif
