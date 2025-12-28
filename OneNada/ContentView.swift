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
    @State private var selectedTab = 0
    @State private var showPaywall = false
    @State private var isAuthenticated = false
    @State private var isRevenueCatSetup = false
    @State private var isCheckingAuth = true
    
    // Reservation state
    @State private var reservedNumber: Int? = nil
    @State private var reservationStartTime: Date? = nil
    
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
                // Show member number reservation for authenticated but non-subscribed users
                MemberNumberReservationView(
                    showPaywall: $showPaywall,
                    reservedNumber: $reservedNumber,
                    reservationStartTime: $reservationStartTime
                )
            } else {
                // Show main app for subscribers
                MainAppView(selectedTab: $selectedTab, modelContext: modelContext)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywallView(
                reservedNumber: reservedNumber,
                reservationStartTime: reservationStartTime,
                onTimerExpired: {
                    // Clear reservation when timer expires
                    reservedNumber = nil
                    reservationStartTime = nil
                }
            )
            .environmentObject(revenueCatManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
            isAuthenticated = false
            isRevenueCatSetup = false
            // Clear reservation on sign out
            reservedNumber = nil
            reservationStartTime = nil
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
