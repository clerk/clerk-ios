//
//  SwiftUIView.swift
//
//
//  Created by Mike Pitre on 10/4/23.
//

#if os(iOS)

import SwiftUI

enum AsyncButtonOptions: CaseIterable {
    case disableButton
    case showProgressView
}

struct AsyncButton<Label: View>: View {
    init(
        options: Set<AsyncButtonOptions> = [.disableButton, .showProgressView],
        role: ButtonRole? = nil,
        action: @escaping () async -> Void,
        label: @escaping () -> Label
    ) {
        self.options = options
        self.role = role
        self.action = action
        self.label = label
    }
    
    var options = Set(AsyncButtonOptions.allCases)
    var role: ButtonRole?
    var action: () async -> Void
    @ViewBuilder var label: () -> Label
    
    @State private var isDisabled = false
    @State private var showProgressView = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.clerkTheme) private var clerkTheme
    
    // Combines environment value and local state
    private var disabled: Bool {
        !isEnabled || isDisabled
    }
    
    var body: some View {
        Button(role: role) {
            if options.contains(.disableButton) {
                isDisabled = true
            }
            
            if options.contains(.showProgressView) {
                showProgressView = true
            }
            
            Task {
                await action()
                isDisabled = false
                showProgressView = false
            }
        } label: {
            label()
                .opacity(disabled ? 0.3 : 1)
                .opacity(showProgressView ? 0 : 1)
                .overlay {
                    if showProgressView {
                        ProgressView()
                    }
                }
        }
        .disabled(disabled)
        .animation(.default, value: disabled)
        .animation(.default, value: showProgressView)
    }
}

#Preview {
    VStack {
        AsyncButton {
            try? await Task.sleep(for: .seconds(1))
        } label: {
            Text("Button")
                .padding()
        }
        .buttonStyle(ClerkPrimaryButtonStyle())
        
        AsyncButton {
            try? await Task.sleep(for: .seconds(1))
        } label: {
            Text("Button")
                .padding()
        }
        .buttonStyle(ClerkSecondaryButtonStyle())
        
        AsyncButton {
            try? await Task.sleep(for: .seconds(1))
        } label: {
            Text("Button")
                .padding()
        }
        .buttonStyle(ClerkDangerButtonStyle())
    }
    
}

#endif
