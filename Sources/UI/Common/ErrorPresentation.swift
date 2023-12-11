//
//  ErrorPresentation.swift
//
//
//  Created by Mike Pitre on 12/11/23.
//

import SwiftUI
import Clerk

public struct ErrorWrapper: Identifiable {
    public let id = UUID()
    public let error: Error
}

struct ErrorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.clerkTheme) private var clerkTheme
    
    let errorWrapper: ErrorWrapper
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Oops! Something went wrong.")
                        .font(.body.weight(.medium))
                    Text(errorWrapper.error.localizedDescription)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("OK")
                    .font(.caption2.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .foregroundStyle(clerkTheme.colors.primaryButtonTextColor)
                    .background(clerkTheme.colors.primary)
                    .clipShape(.rect(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(30)
        .padding(.top, 20)
        .dismissButtonOverlay()
    }
}

struct ClerkErrorViewModifier: ViewModifier {
    @Binding var errorWrapper: ErrorWrapper?
    
    func body(content: Content) -> some View {
        content
            .sheet(item: $errorWrapper) { errorWrapper in
                ErrorView(errorWrapper: errorWrapper)
                    .presentationDetents([.height(250)])
                    .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    
    func clerkErrorPresenting(_ errorWrapper: Binding<ErrorWrapper?>) -> some View {
        modifier(ClerkErrorViewModifier(errorWrapper: errorWrapper))
    }
    
}

#Preview {
    Color(.systemBackground)
        .sheet(item: .constant(ErrorWrapper(error: ClerkClientError(message: "Password is incorrect. Try again, or use another method.")))) { errorWrapper in
            ErrorView(errorWrapper: errorWrapper)
                .presentationDetents([.height(250)])
                .presentationDragIndicator(.visible)
        }
}
