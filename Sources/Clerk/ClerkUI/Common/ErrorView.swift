//
//  ErrorView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/8/25.
//

#if os(iOS)

import SwiftUI

struct ErrorView: View {
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    struct ActionConfig {
        let text: LocalizedStringKey
        let action: () async -> Void
    }

    let error: Error
    var action: ActionConfig?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image("icon-warning", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(theme.colors.danger)
                .padding(12)
                .background(theme.colors.backgroundDanger, in: .circle)

            VStack(alignment: .leading, spacing: 12) {
                Text("Whoops, something is wrong", bundle: .module)
                    .font(theme.fonts.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(theme.colors.text)
                    .frame(minHeight: 28)

                Text(error.localizedDescription)
                    .font(theme.fonts.body)
                    .foregroundStyle(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                if let action {
                    AsyncButton {
                        dismiss()
                        await action.action()
                    } label: { isRunning in
                        Text(action.text, bundle: .module)
                            .frame(maxWidth: .infinity)
                            .overlayProgressView(isActive: isRunning) {
                                SpinnerView(color: theme.colors.textOnPrimaryBackground)
                            }
                    }
                    .buttonStyle(.primary())
                    .simultaneousGesture(TapGesture())
                }

                Button {
                    dismiss()
                } label: {
                    Text("Close", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary())
                .simultaneousGesture(TapGesture())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ErrorView(
        error: ClerkClientError(message: "Similique qui enim placeat tempore. Labore voluptates aliquam est quaerat aut perferendis similique."),
        action: .init(
            text: "Call to action",
            action: {
                try! await Task.sleep(for: .seconds(2))
            })
    )
    .padding()
    .environment(\.clerkTheme, .clerk)
}

#endif
