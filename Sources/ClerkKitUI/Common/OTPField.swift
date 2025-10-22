//
//  OTPField.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

#if os(iOS)

import SwiftUI

struct OTPField: View {
    @Environment(\.clerkTheme) private var theme

    @Binding var code: String
    var numberOfInputs: Int = 6
    @Binding var fieldState: FieldState
    @FocusState.Binding var isFocused: Bool
    var onCodeEntry: ((String) async -> Void)

    enum FieldState {
        case `default`
        case error
    }

    @State private var cursorAnimating = false
    @State private var inputSize = CGSize.zero
    @State private var errorTrigger = false

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<numberOfInputs, id: \.self) { index in
                otpFieldInput(index: index)
            }
        }
        .phaseAnimator(
            [0, 10, -10, 10, -5, 5, 0], trigger: errorTrigger,
            content: { content, offset in
                content
                    .offset(x: offset)
            },
            animation: { _ in
                .linear(duration: 0.06)
            }
        )
        .sensoryFeedback(.error, trigger: errorTrigger)
        .overlay {
            TextField("", text: $code)
                .focused($isFocused)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: code) { oldValue, newValue in
            let previousCode = String(oldValue.prefix(numberOfInputs))
            self.code = String(newValue.prefix(numberOfInputs))
            if previousCode == code { return }

            if code.count == numberOfInputs {
                fieldState = .default
                Task { await onCodeEntry(code) }
            } else if code.isEmpty {
                fieldState = .default
            }
        }
        .onChange(
            of: fieldState,
            { oldValue, newValue in
                if newValue == .error {
                    DispatchQueue.main.async {
                        errorTrigger.toggle()
                    }
                }
            }
        )
        .onAppear {
            fieldState = .default
        }
    }

    @ViewBuilder
    func otpFieldInput(index: Int) -> some View {
        var isSelected: Bool {
            isFocused && code.count == index
        }

        ZStack {
            if code.count > index {
                let startIndex = code.startIndex
                let charIndex = code.index(startIndex, offsetBy: index)
                let charToString = String(code[charIndex])
                Text(charToString)
            } else {
                Text(verbatim: " ")
            }
        }
        .monospacedDigit()
        .padding(.vertical)
        .frame(maxWidth: .infinity, minHeight: 56)
        .onGeometryChange(
            for: CGSize.self,
            of: { geometry in
                geometry.size
            },
            action: { newValue in
                inputSize = newValue
            }
        )
        .overlay {
            if isSelected {
                Rectangle()
                    .frame(maxWidth: 2, maxHeight: 0.35 * inputSize.height)
                    .foregroundStyle(theme.colors.primary)
                    .animation(
                        .easeInOut.speed(0.75).repeatForever(),
                        body: { content in
                            content
                                .opacity(cursorAnimating ? 1 : 0)
                        }
                    )
                    .onAppear {
                        cursorAnimating.toggle()
                    }
            }
        }
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.foreground)
        .background(theme.colors.input)
        .clipShape(.rect(cornerRadius: theme.design.borderRadius))
        .overlay {
            RoundedRectangle(cornerRadius: theme.design.borderRadius)
                .strokeBorder(theme.colors.input)
        }
        .clerkFocusedBorder(
            isFocused: fieldState == .error || isSelected,
            state: fieldState == .error ? .error : .default
        )
    }
}

#Preview {
    @Previewable @State var code = ""
    @Previewable @State var fieldState1 = OTPField.FieldState.default
    @Previewable @State var fieldState2 = OTPField.FieldState.default
    @Previewable @FocusState var isFocused: Bool

    VStack(spacing: 20) {
        OTPField(code: $code, fieldState: $fieldState1, isFocused: $isFocused) { code in
            fieldState1 = .default
        }

        OTPField(code: $code, fieldState: $fieldState2, isFocused: $isFocused) { code in
            fieldState2 = .error
        }
    }
    .padding()
    //    .environment(\.dynamicTypeSize, .accessibility5)
}

#endif
