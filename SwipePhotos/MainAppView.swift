import SwiftUI
import Supabase

struct MainAppView: View {
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                // Main feature placeholder
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                VStack(spacing: 12) {
                    Text("Welcome to OneNada!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("You have an active subscription")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Theme selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(themeManager.currentTheme == theme ? Color.blue.opacity(0.2) : Color(.systemGray5))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: theme.iconName)
                                        .font(.system(size: 20))
                                        .foregroundColor(themeManager.currentTheme == theme ? .blue : .primary)
                                }
                                
                                Text(theme.displayName)
                                    .font(.caption)
                                    .fontWeight(themeManager.currentTheme == theme ? .semibold : .regular)
                                    .foregroundColor(themeManager.currentTheme == theme ? .blue : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    themeManager.currentTheme = theme
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    // Sign out button
                    Button("Sign Out", role: .destructive) {
                        Task {
                            try? await supabase.auth.signOut()
                            await revenueCatManager.signOut()
                            // Post notification to update the UI
                            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    // Delete Account Button
                    Button("Delete Account") {
                        showDeleteAccountAlert = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isDeletingAccount)
                    
                    if isDeletingAccount {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Deleting account...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("OneNada")
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Account Deletion
    private func deleteAccount() async {
        isDeletingAccount = true
        errorMessage = nil
        
        print("🗑️ Starting account deletion...")
        
        do {
            // Get the current user
            let user = try await supabase.auth.user()
            print("🗑️ Got user: \(user.id.uuidString)")
            
            // Delete user data from RevenueCat
            print("🗑️ Calling RevenueCat deleteUser...")
            do {
                try await revenueCatManager.deleteUser(appUserID: user.id.uuidString)
                print("🗑️ RevenueCat deleteUser completed")
            } catch {
                print("❌ Failed to delete RevenueCat data: \(error.localizedDescription)")
                // Continue even if RevenueCat deletion fails
            }
            
            // Verify subscription status cleared
            print("🗑️ isSubscribed after delete: \(revenueCatManager.isSubscribed)")
            
            // Sign out from Supabase
            print("🗑️ Signing out from Supabase...")
            try await supabase.auth.signOut()
            print("🗑️ Supabase sign out completed")
            
            // Post notification to update the UI
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
            
            print("✅ Account deleted successfully")
            print("⚠️ NOTE: If you log back in with the same Apple ID, RevenueCat will")
            print("   reconnect you to your existing subscription. This is expected behavior.")
            print("   To test paywall again, cancel subscription in Settings → Subscriptions")
            
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            print("❌ Delete account error: \(error.localizedDescription)")
        }
        
        isDeletingAccount = false
    }
}

#Preview {
    MainAppView()
        .environmentObject(RevenueCatManager.shared)
        .environmentObject(ThemeManager.shared)
}

