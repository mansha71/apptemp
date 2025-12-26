import SwiftUI
import SwiftData
import Supabase

extension Notification.Name {
    static let userDidSignIn = Notification.Name("userDidSignIn")
    static let userDidSignOut = Notification.Name("userDidSignOut")
    static let subscriptionDidComplete = Notification.Name("subscriptionDidComplete")
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    @State private var showPaywall = false
    @State private var isAuthenticated = false
    @State private var isRevenueCatSetup = false
    @State private var isCheckingAuth = true
    
    var body: some View {
        Group {
            if isCheckingAuth {
                // Show loading while checking authentication state
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
                .task {
                    await checkInitialAuthState()
                }
            } else if !isAuthenticated {
                // Show authentication first
                AuthView()
                    .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { notification in
                        if let userID = notification.object as? String {
                            isAuthenticated = true
                            // Set up RevenueCat with user ID
                            Task {
                                await revenueCatManager.setupWithUserID(userID)
                                isRevenueCatSetup = true
                            }
                        }
                    }
            } else if !isRevenueCatSetup {
                // Loading state while setting up RevenueCat
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Setting up your account...")
                        .foregroundColor(.secondary)
                }
            } else if !revenueCatManager.isSubscribed {
                // Show onboarding/paywall for authenticated but non-subscribed users
                OnboardingView(showPaywall: $showPaywall)
            } else {
                // Show main app for subscribers
                MainAppView(selectedTab: $selectedTab, modelContext: modelContext)
            }
        }
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywallView()
                .environmentObject(revenueCatManager)
                .environmentObject(themeManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
            isAuthenticated = false
            isRevenueCatSetup = false
        }
    }
    
    @MainActor
    private func checkInitialAuthState() async {
        do {
            // Check if user is already authenticated with Supabase
            let currentUser = try await supabase.auth.user()
            
            // User is authenticated
            isAuthenticated = true
            print("✅ User already authenticated: \(currentUser.id.uuidString)")
            
            // Set up RevenueCat with the existing user ID
            await revenueCatManager.setupWithUserID(currentUser.id.uuidString)
            isRevenueCatSetup = true
            
        } catch {
            // User is not authenticated
            print("ℹ️ User not authenticated, showing auth screen")
            isAuthenticated = false
        }
        
        isCheckingAuth = false
    }
}

struct OnboardingView: View {
    @Binding var showPaywall: Bool
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State private var spotsRemaining: Int?
    
    var body: some View {
        VStack(spacing: 30) {
            // Sign out button in top-right corner
            HStack {
                Spacer()
                Button(action: {
                    Task {
                        try? await supabase.auth.signOut()
                        await revenueCatManager.signOut()
                        // Post notification to update the UI
                        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
                    }
                }) {
                    Text("Sign Out")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Text("Welcome to OneNada")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if let spots = spotsRemaining {
                    Text("There are \(spots) spots left")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Loading available spots...")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            Button(action: {
                showPaywall = true
            }) {
                Text("Become a Member")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.primary)
                    .foregroundColor(Color(.systemBackground))
                    .cornerRadius(12)
            }
        }
        .padding()
        .task {
            await fetchAvailableSpots()
        }
    }
    
    private func fetchAvailableSpots() async {
        do {
            // Use RPC function to get accurate count (avoids 1000 row limit)
            let count: Int = try await supabase
                .rpc("get_available_spots_count")
                .execute()
                .value
            
            print("✅ Found \(count) available spots")
            
            await MainActor.run {
                spotsRemaining = count
            }
        } catch {
            print("❌ Failed to fetch available spots: \(error)")
            // Default to showing nothing if fetch fails
        }
    }
}

struct MainAppView: View {
    @Binding var selectedTab: Int
    let modelContext: ModelContext
    @EnvironmentObject var revenueCatManager: RevenueCatManager

    var body: some View {
        NavigationStack {
            ProfileView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SharedModelContainer.shared.container)
        .environmentObject(RevenueCatManager.shared)
        .environmentObject(ThemeManager.shared)
}
