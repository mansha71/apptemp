import SwiftUI
import AuthenticationServices
import Supabase
import RevenueCat

struct ProfileInsert: Codable {
    let id: String
    let email: String
    let name: String?
    let profileImageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case profileImageUrl = "profile_image_url"
    }
}

struct ProfileUpdate: Codable {
    let name: String?
    let profileImageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case profileImageUrl = "profile_image_url"
    }
}

struct AuthView: View {
    @State var isSignedIn = false
    @State var user: User?
    @State var errorMessage: String?
    @State var isLoading = false
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to SwipePhotos")
                .font(.title)
                .fontWeight(.bold)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Apple Sign In Button
            SignInWithAppleButton { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                Task {
                    await handleAppleSignIn(result)
                }
            }
            .frame(height: 50)
            .signInWithAppleButtonStyle(.black)
            
            if isLoading {
                ProgressView()
            }
            
            if isSignedIn {
                VStack(spacing: 12) {
                    Text("Signed in!")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    Text(user?.email ?? "User")
                        .font(.caption)
                    
                    Button(action: {
                        Task {
                            do {
                                try await supabase.auth.signOut()
                                isSignedIn = false
                                user = nil
                                errorMessage = nil
                                // Sign out from RevenueCat too
                                await revenueCatManager.signOut()
                                // Post sign-out notification
                                NotificationCenter.default.post(name: .userDidSignOut, object: nil)
                            } catch {
                                errorMessage = "Sign out failed: \(error.localizedDescription)"
                            }
                        }
                    }) {
                        Text("Sign Out")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
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
            
            // Update user profile with full name from Apple
            await updateAppleUserProfile(credential: credential)
            
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
    
    @MainActor
    private func updateAppleUserProfile(credential: ASAuthorizationAppleIDCredential) async {
        await handlePostSignIn()
        await ensureProfileExists(credential: credential)
    }
    
    private func ensureProfileExists(credential: ASAuthorizationAppleIDCredential? = nil) async {
        do {
            let currentUser = try await supabase.auth.user()
            print("Checking profile for user: \(currentUser.id.uuidString)")
            
            let existingProfiles: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: currentUser.id.uuidString)
                .execute()
                .value
            
            if existingProfiles.isEmpty {
                print("No profile found, creating one...")
                await createProfileManually(user: currentUser, credential: credential)
            } else {
                print("Profile already exists")
            }
            
        } catch {
            print("Error checking/creating profile: \(error.localizedDescription)")
        }
    }
    
    private func createProfileManually(user: User, credential: ASAuthorizationAppleIDCredential? = nil) async {
        do {
            var name: String? = nil
            
            if let credential = credential, let fullName = credential.fullName {
                var nameParts: [String] = []
                if let givenName = fullName.givenName {
                    nameParts.append(givenName)
                }
                if let middleName = fullName.middleName {
                    nameParts.append(middleName)
                }
                if let familyName = fullName.familyName {
                    nameParts.append(familyName)
                }
                let fullNameString = nameParts.joined(separator: " ")
                if !fullNameString.isEmpty {
                    name = fullNameString
                }
            }
            
            let newProfile = ProfileInsert(
                id: user.id.uuidString,
                email: user.email ?? "",
                name: name,
                profileImageUrl: nil
            )
            
            try await supabase
                .from("profiles")
                .insert(newProfile)
                .execute()
            
            print("Profile created successfully")
            
        } catch {
            print("Failed to create profile manually: \(error.localizedDescription)")
        }
    }
}

#Preview {
    AuthView()
}
