//
//  UserProfilePasskeyRenameView.swift
//
//
//  Created by Mike Pitre on 9/10/24.
//

#if os(iOS)

import SwiftUI

struct UserProfilePasskeyRenameView: View {
    let passkey: Passkey
    
    @Environment(\.dismiss) private var dismiss
    @State private var passkeyName: String = ""
    @State private var errorWrapper: ErrorWrapper?
    @FocusState var isFocused: Bool

    private var saveDisabled: Bool {
        passkey.name == passkeyName ||
        passkeyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Rename Passkey")
                        .font(.title2.weight(.bold))
                    
                    Text("You can change the passkey name to make it easier to find.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading) {
                    Text("Name of passkey")
                        .font(.footnote.weight(.medium))
                    CustomTextField(text: $passkeyName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($isFocused)
                        .task {
                            isFocused = true
                        }
                }
                
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkSecondaryButtonStyle())
                    
                    AsyncButton {
                        await updateName(passkeyName)
                        dismiss()
                    } label: {
                        Text("Save")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkPrimaryButtonStyle())
                    .disabled(saveDisabled)
                }
            }
            .padding()
            .padding(.top, 30)
        }
        .dismissButtonOverlay()
        .clerkErrorPresenting($errorWrapper)
        .task {
            passkeyName = passkey.name
        }
    }
    
}

extension UserProfilePasskeyRenameView {
    
    func updateName(_ name: String) async {
        do {
            try await passkey.update(name: name)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
        }
    }
    
}

#Preview {
    UserProfilePasskeyRenameView(passkey: .mock)
}

#endif
