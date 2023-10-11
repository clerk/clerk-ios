//
//  SwiftUIView.swift
//
//
//  Created by Mike Pitre on 10/4/23.
//

import SwiftUI

public struct AsyncButton<Label: View>: View {
    public init(
        options: Set<AsyncButton<Label>.Options> = .init(),
        action: @escaping () async -> Void,
        label: @escaping () -> Label
    ) {
        self.options = options
        self.action = action
        self.label = label
    }
    
    var options = Set(Options.allCases)
    var action: () async -> Void
    @ViewBuilder var label: () -> Label
    
    @State private var isDisabled = false
    @State private var showProgressView = false
    
    public var body: some View {
        Button(
            action: {
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
            },
            label: {
                ZStack {
                    label().opacity(showProgressView ? 0 : 1)
                    
                    if showProgressView {
                        ProgressView()
                    }
                }
            }
        )
        .disabled(isDisabled)
        .animation(.default, value: isDisabled)
        .animation(.default, value: showProgressView)
    }
}

#Preview {
    AsyncButton(options: [.disableButton, .showProgressView]) {
        try? await Task.sleep(for: .seconds(1))
    } label: {
        Text("Button")
    }
}

extension AsyncButton {
    public enum Options: CaseIterable {
        case disableButton
        case showProgressView
    }
}
