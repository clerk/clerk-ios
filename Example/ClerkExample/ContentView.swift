//
//  ContentView.swift
//  ClerkExample
//
//  Created by Mike Pitre on 10/2/23.
//

#if !os(macOS)

import SwiftUI
import Clerk

struct ContentView: View {
    @EnvironmentObject private var clerk: Clerk
    
    @State private var emailAddress: String = ""
    @State private var password: String = ""
    @State private var code: String = ""
    @State private var didSendCode = false
    
    private func signUpAction() async {
        do {                        
            try await clerk
                .client
                .signUp
                .create(.init(password: password, emailAddress: emailAddress))
            
            try await clerk
                .client
                .signUp
                .prepareVerification(.init(strategy: .emailCode))
            
            withAnimation(.bouncy) { didSendCode = true }
        } catch {
            dump(error)
        }
    }
    
    private func verifyAction() async {
        do {
            try await clerk
                .client
                .signUp
                .attemptVerification(.init(
                    strategy: .emailCode,
                    code: code
                ))
        } catch {
            dump(error)
        }
    }
    
    private func signInAction() async {
        do {
            try await clerk
                .client
                .signIn
                .create(.init(
                    identifier: emailAddress,
                    password: password
                ))
        } catch {
            dump(error)
        }
    }
    
    private func deleteClientAction() async {
        do {
            try await clerk
                .client
                .destroy()
        } catch {
            dump(error)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack {
                if !clerk.client.sessions.isEmpty {
                    Text("SIGN UP COMPLETE!")
                        .font(.headline)
                        .transition(.scale.animation(.bouncy))
                        .padding()
                }
                                
                TextField("Email", text: $emailAddress)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .padding()
                            
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .padding()
                
                AsyncButton(
                    options: [.disableButton, .showProgressView],
                    action: signUpAction
                ) {
                    Text("Sign Up!")
                }
                .padding()
                
                AsyncButton(
                    options: [.disableButton, .showProgressView],
                    action: signInAction
                ) {
                    Text("Sign In!")
                }
                .padding()
                
                AsyncButton(
                    options: [.disableButton, .showProgressView],
                    action: deleteClientAction
                ) {
                    Text("Destroy Client")
                }
                .padding()
                
                if didSendCode {
                    VStack {
                        TextField("Code", text: $code)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .padding()
                        
                        AsyncButton(
                            options: [.disableButton, .showProgressView],
                            action: verifyAction
                        ) {
                            Text("Verify!")
                        }
                        .padding()
                    }
                    .transition(.slide)
                }
            }
            .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(Clerk.mock)
    }
}

#endif
