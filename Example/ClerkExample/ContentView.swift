//
//  ContentView.swift
//  ClerkExample
//
//  Created by Mike Pitre on 10/2/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct ContentView: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) var clerkTheme
    
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
                
                Button(action: {
                    Task { await signUpAction() }
                }, label: {
                    Text("Sign Up!")
                })
                .padding()
                
                Button(action: {
                    Task { await signInAction() }
                }, label: {
                    Text("Sign In!")
                })
                .padding()
                
                Button(action: {
                    Task { await deleteClientAction() }
                }, label: {
                    Text("Delete Client")
                })
                .padding()
                
                if didSendCode {
                    VStack {
                        TextField("Code", text: $code)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .padding()
                        
                        Button(action: {
                            Task { await verifyAction() }
                        }, label: {
                            Text("Verify!")
                        })
                        .padding()
                    }
                    .transition(.slide)
                }
            }
            .padding()
            .tint(clerkTheme.colors.primary)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(Clerk.mock)
}

#endif
