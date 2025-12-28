import SwiftUI
import AuthenticationServices
import Supabase
import RevenueCat

struct AuthView: View {
    @State var isSignedIn = false
    @State var user: User?
    @State var errorMessage: String?
    @State var isLoading = false
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // MARK: - Welcome Section
                VStack(spacing: 8) {
                    Text("Welcome to")
                        .font(.title2)
                        .fontWeight(.light)
                        .foregroundColor(.secondary)
                    
                    Text("OneNada")
                        .font(.system(size: 74, weight: .black, design: .default))
                        .tracking(4)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // MARK: - Sign In Section
                VStack(spacing: 20) {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Apple Sign In Button
                    SignInWithAppleButton { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        Task {
                            await handleAppleSignIn(result)
                        }
                    }
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .signInWithAppleButtonStyle(.black)
                    .cornerRadius(12)
                    
                    if isLoading {
                        ProgressView()
                            .tint(.primary)
                            .padding(.top, 8)
                    }
                    
                    if isSignedIn {
                        VStack(spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.primary)
                                Text("Signed in")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            Text(user?.email ?? "User")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                Task {
                                    do {
                                        try await supabase.auth.signOut()
                                        isSignedIn = false
                                        user = nil
                                        errorMessage = nil
                                        await revenueCatManager.signOut()
                                        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
                                    } catch {
                                        errorMessage = "Sign out failed: \(error.localizedDescription)"
                                    }
                                }
                            }) {
                                Text("Sign Out")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.primary)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                    .frame(height: 60)
                
                // Footer text
                Text("By continuing, you agree to our Terms of Service")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Apple Sign In
    @MainActor
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Failed to get Apple ID credential"
                return
            }
            
            guard let idToken = credential.identityToken
                .flatMap({ String(data: $0, encoding: .utf8) })
            else {
                errorMessage = "Unable to extract identity token"
                return
            }
            
            try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken
                )
            )
            
            // Profile is auto-created by database trigger, just handle post sign-in
            await handlePostSignIn()
            
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            print("Sign in with Apple failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    private func handlePostSignIn() async {
        do {
            let currentUser = try await supabase.auth.user()
            user = currentUser
            isSignedIn = true
            errorMessage = nil
            
            // Post notification with user ID for ContentView to handle
            NotificationCenter.default.post(
                name: .userDidSignIn,
                object: currentUser.id.uuidString
            )
            
        } catch {
            errorMessage = "Failed to get user: \(error.localizedDescription)"
        }
    }
}

#Preview {
    AuthView()
}

