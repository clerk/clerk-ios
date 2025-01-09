//
//  LocalAuthPresenting.swift
//
//
//  Created by Mike Pitre on 3/28/24.
//

#if os(iOS)

import SwiftUI
import UIKit
import SimpleKeychain

/**
 This modifier enables local authentication on the app being put into an active state.
 
 You should apply this modifier to the root view of your application. Most likely in your `App` file.
 */
public struct LocalAuthOnForegroundModifier: ViewModifier {
    var clerk = Clerk.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var isPresented = false
    @State private var shouldTryAuth = true
    @State private var shouldAnimate = false
    @State private var hostingController: UIHostingController<AnyView>?
    
    var lockPhase: LockPhase = .background
    
    public enum LockPhase {
        case inactive, background
    }
    
    private var hasSession: Bool {
        do {
            return try SimpleKeychain().hasItem(forKey: "lastActiveSessionId")
        } catch {
            return false
        }
    }
    
    public func body(content: Content) -> some View {
        content
            .task {
                isPresented = true
            }
            .onChange(of: isPresented) { _, newValue in
                if newValue && hasSession {
                    showLocalAuthView(withAnimation: shouldAnimate) {
                        shouldAnimate = true
                    }
                } else {
                    dismissView(withAnimation: shouldAnimate)
                }
            }
            .onChange(of: scenePhase) { _, newValue in
                guard hasSession else { return }
                switch newValue {
                case .active:
                    if isPresented {
                        Task { await authenticate() }
                    }
                case .background:
                    if lockPhase == .background || lockPhase == .inactive {
                        shouldTryAuth = true
                        isPresented = true
                    }
                case .inactive:
                    if lockPhase == .inactive {
                        shouldTryAuth = true
                        isPresented = true
                    }
                @unknown default:
                    return
                }
            }
    }
    
    @MainActor
    private func authenticate() async {
        guard shouldTryAuth else { return }
        do {
            try await Clerk.LocalAuth.authenticateWithBiometrics()
            isPresented = false
        } catch {
            Clerk.LocalAuth.context.invalidate()
            shouldTryAuth = false
        }
    }
    
    @MainActor
    private func signOut() async {
        do {
            try await clerk.signOut()
            isPresented = false
        } catch {
            dump(error)
        }
    }
}

fileprivate struct LocalAuthOverlay: View {
    var clerk = Clerk.shared
    let onUnlock: () -> Void
    let onSignOut: () -> Void
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                OrgLogoView()
                    .frame(width: 80, height: 80)
                Spacer()
                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                VStack {
                    Button {
                        onUnlock()
                    } label: {
                        Text("Unlock")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkPrimaryButtonStyle())
                    
                    AsyncButton {
                        onSignOut()
                    } label: {
                        Text("Sign Out")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkSecondaryButtonStyle())
                }
                .padding()
            }
        }
    }
}

extension View {
    /**
     This modifier enables local authentication on the app being put into an active state.
     
     You should apply this modifier to the root view of your application. Most likely in your `App` file.
     */
    @MainActor
    public func localAuthOnForeground(lockPhase: LocalAuthOnForegroundModifier.LockPhase = .background) -> some View {
        modifier(LocalAuthOnForegroundModifier(lockPhase: lockPhase))
    }
}

#Preview {
    LocalAuthOverlay(onUnlock: {}, onSignOut: {})
}

private extension LocalAuthOnForegroundModifier {
    
    func showLocalAuthView(withAnimation: Bool = true, completion: @escaping () -> Void = {}) {
        DispatchQueue.main.async {
            KeyboardHelpers.dismissKeyboard()
            
            let swiftUIView = LocalAuthOverlay(onUnlock: {
                Task {
                    shouldTryAuth = true
                    await authenticate()
                }
            }, onSignOut: {
                Task {
                    await signOut()
                }
            })
            
            hostingController = UIHostingController(rootView: AnyView(swiftUIView))
            hostingController?.view.backgroundColor = .clear
            hostingController?.view.frame = CGRect(
                x: 0,
                y: 0,
                width: UIScreen.main.bounds.width,
                height: UIScreen.main.bounds.height
            )
            hostingController?.view.alpha = 0
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.addSubview(hostingController!.view)
                
                hostingController?.view.center = window.center
                
                UIView.animate(withDuration: withAnimation && lockPhase == .inactive ? 0.2 : 0) {
                    hostingController?.view.alpha = 1
                } completion: { done in
                    completion()
                }
            }
        }
    }
    
    func dismissView(withAnimation: Bool = true, completion: @escaping () -> Void = {}) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: withAnimation ? 0.2 : 0) {
                hostingController?.view.alpha = 0
            } completion: { done in
                if done {
                    hostingController?.view.removeFromSuperview()
                    hostingController = nil
                    completion()
                }
            }
        }
    }
}

#endif
