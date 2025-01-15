//
//  LegalConsentView.swift
//  Clerk
//
//  Created by Mike Pitre on 1/15/25.
//

#if os(iOS)

import SwiftUI

extension LegalConsentView {
    @Observable
    @MainActor
    final class ViewModel {
                
        var privacyPolicyUrl: URL? {
            guard let urlString = Clerk.shared.environment?.displayConfig.privacyPolicyUrl else { return nil }
            return URL(string: urlString)
        }
        
        var termsURL: URL? {
            guard let urlString = Clerk.shared.environment?.displayConfig.termsUrl else { return nil }
            return URL(string: urlString)
        }
        
        var markdownString: String {
            if termsURL == nil && privacyPolicyUrl == nil {
                return ""
            }
            
            var string = "I agree to"
            
            if let termsURL = termsURL {
                string += " [Terms of Service](\(termsURL.absoluteString))"
            }
            
            if termsURL != nil && privacyPolicyUrl != nil {
                string += " and"
            }
            
            if let privacyPolicyUrl = privacyPolicyUrl {
                string += " [Privacy Policy](\(privacyPolicyUrl.absoluteString))"
            }
            
            string += "."
            
            return string
        }
        
    }
}

struct LegalConsentView: View {
    var clerk = Clerk.shared
    private let viewModel = ViewModel()
    @Environment(ClerkTheme.self) private var clerkTheme
    
    @Binding var agreedToLegalConsent: Bool
        
    var body: some View {
        HStack {
            if !viewModel.markdownString.isEmpty {
                CheckBoxView(isSelected: $agreedToLegalConsent)
                    .frame(width: 18, height: 18)
                Text(.init(viewModel.markdownString))
                    .font(.caption)
                    .tint(clerkTheme.colors.linkColor)
            }
        }
    }
    
}

#Preview {
    LegalConsentView(agreedToLegalConsent: .constant(true))
        .environment(Clerk.shared)
        .environment(ClerkTheme.clerkDefault)
}

#endif
