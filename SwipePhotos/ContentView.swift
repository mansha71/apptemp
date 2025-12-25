import SwiftUI
import Supabase

extension Notification.Name {
    static let userDidSignIn = Notification.Name("userDidSignIn")
    static let userDidSignOut = Notification.Name("userDidSignOut")
}

struct ContentView: View {
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAuthenticated = false
    @State private var isRevenueCatSetup = false
    @State private var isCheckingAuth = true
    
    var body: some View {
        Group {
            // DEBUG: Log current state every time view body is evaluated
            let _ = print("")
            let _ = print("📍 ============ ContentView RENDER ============")
            let _ = print("📍 isCheckingAuth = \(isCheckingAuth)")
            let _ = print("📍 isAuthenticated = \(isAuthenticated)")
            let _ = print("📍 isRevenueCatSetup = \(isRevenueCatSetup)")
            let _ = print("📍 revenueCatManager.isSubscribed = \(revenueCatManager.isSubscribed)")
            let _ = print("📍 ============================================")
            
            if isCheckingAuth {
                // Show loading while checking authentication state
                let _ = print("🔄 SHOWING: Loading screen (checking auth)")
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
                let _ = print("🔐 SHOWING: AuthView")
                AuthView()
                    .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { notification in
                        print("📣 Received userDidSignIn notification")
                        if let userID = notification.object as? String {
                            print("📣 User ID from notification: \(userID)")
                            isAuthenticated = true
                            // Set up RevenueCat with user ID
                            Task {
                                print("⏳ Starting RevenueCat setup...")
                                await revenueCatManager.setupWithUserID(userID)
                                print("✅ RevenueCat setup complete")
                                print("📊 isSubscribed after setup = \(revenueCatManager.isSubscribed)")
                                isRevenueCatSetup = true
                                print("📍 Set isRevenueCatSetup = true")
                            }
                        }
                    }
            } else if !isRevenueCatSetup {
                // Loading state while setting up RevenueCat
                let _ = print("🔄 SHOWING: Setting up account screen")
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Setting up your account...")
                        .foregroundColor(.secondary)
                }
            } else if !revenueCatManager.isSubscribed {
                // Show paywall for authenticated but non-subscribed users
                let _ = print("💳 SHOWING: SubscriptionPaywallView (user NOT subscribed)")
                SubscriptionPaywallView()
                    .environmentObject(revenueCatManager)
                    .environmentObject(themeManager)
            } else {
                // Show main app for subscribers
                let _ = print("🏠 SHOWING: MainAppView (user IS subscribed)")
                MainAppView()
                    .environmentObject(revenueCatManager)
                    .environmentObject(themeManager)
            }
        }
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
            isAuthenticated = false
            isRevenueCatSetup = false
        }
    }
    
    @MainActor
    private func checkInitialAuthState() async {
        print("")
        print("🔍 ====== checkInitialAuthState START ======")
        do {
            // Check if user is already authenticated with Supabase
            print("🔍 Checking Supabase auth state...")
            let currentUser = try await supabase.auth.user()
            
            // User is authenticated
            isAuthenticated = true
            print("✅ User already authenticated: \(currentUser.id.uuidString)")
            
            // Set up RevenueCat with the existing user ID
            print("⏳ Starting RevenueCat setup from checkInitialAuthState...")
            await revenueCatManager.setupWithUserID(currentUser.id.uuidString)
            print("✅ RevenueCat setup complete")
            print("📊 isSubscribed after setup = \(revenueCatManager.isSubscribed)")
            isRevenueCatSetup = true
            print("📍 Set isRevenueCatSetup = true")
            
        } catch {
            // User is not authenticated
            print("ℹ️ User not authenticated: \(error.localizedDescription)")
            print("ℹ️ Will show AuthView")
            isAuthenticated = false
        }
        
        isCheckingAuth = false
        print("🔍 Set isCheckingAuth = false")
        print("🔍 ====== checkInitialAuthState END ======")
        print("🔍 Final state: auth=\(isAuthenticated), rcSetup=\(isRevenueCatSetup), subscribed=\(revenueCatManager.isSubscribed)")
        print("")
    }
}

#Preview {
    ContentView()
        .environmentObject(RevenueCatManager.shared)
        .environmentObject(ThemeManager.shared)
}
