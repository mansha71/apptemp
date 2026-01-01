import SwiftUI
import Supabase
import StoreKit

struct ProfileView: View {
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State var isLoading = false
    @State var profile: UserProfile?
    @State var errorMessage: String?
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var subscriptionTimer: Timer?
    @State private var elapsedTime: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                    } else {
                        // MARK: - Hero Subscription Timer
                        if let subscriptionDate = profile?.subscriptionStartedAt {
                            VStack(spacing: 16) {
                                // Header
                                Text("YOUR JOURNEY")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .tracking(2)
                                    .foregroundColor(.secondary)
                                
                                // Main Timer Display
                                Text(elapsedTime)
                                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                
                                // Subscription Date
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.primary)
                                        .font(.subheadline)
                                    Text("Member since \(subscriptionDate.formatted(date: .long, time: .omitted))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Member Number
                                if let memberNumber = profile?.memberNumber {
                                    VStack(spacing: 4) {
                                        Text("Member")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .tracking(1)
                                            .foregroundColor(.secondary)
                                        
                                        Text("#\(memberNumber)")
                                            .font(.system(size: 48, weight: .black))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.top, 8)
                                }
                                
                                // MARK: - Level Progress Bar
                                LevelProgressView(subscriptionDate: subscriptionDate)
                                    .padding(.top, 16)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .padding(.horizontal, 20)
                            .onAppear {
                                startSubscriptionTimer(from: subscriptionDate)
                            }
                            .onDisappear {
                                subscriptionTimer?.invalidate()
                            }
                        }
                        


                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                        }



                        Spacer()

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
                }
            }
            .padding()
            .navigationTitle("OneNada")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await fetchProfile()
            }
            .refreshable {
                await fetchProfile()
            }
            .onReceive(NotificationCenter.default.publisher(for: .subscriptionDidComplete)) { _ in
                // Refetch profile to get updated subscription_started_at
                Task {
                    await fetchProfile()
                }
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This will permanently delete all your data and settings. This action cannot be undone.")
            }
        }
    }

    func fetchProfile() async {
        // Only show loading indicator if no profile is loaded yet
        if profile == nil {
            isLoading = true
        }
        errorMessage = nil

        do {
            // Get the current user - this will throw if no session exists
            let user = try await supabase.auth.user()

            // Fetch profile from Supabase
            let response: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .execute()
                .value

            if let existingProfile = response.first {
                profile = existingProfile
            } else {
                // Profile should be created by database trigger, wait and retry once
                try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
                
                let retryResponse: [UserProfile] = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: user.id.uuidString)
                    .execute()
                    .value
                
                profile = retryResponse.first
                
                if profile == nil {
                    errorMessage = "Profile not found. Please try again."
                }
            }
        } catch is CancellationError {
            // Task was cancelled (common with pull-to-refresh), ignore silently
        } catch {
            // Don't show error message for session missing - it's expected after sign out
            if error.localizedDescription.contains("sessionMissing") || error.localizedDescription.contains("Auth session is missing") {
                profile = nil
            }
        }

        isLoading = false
    }

    // MARK: - Account Deletion

    func deleteAccount() async {
        isDeletingAccount = true
        errorMessage = nil

        do {
            // Call the delete_user RPC function - cascade will handle cleanup
            try await supabase.rpc("delete_user").execute()

            // Sign out the user
            try? await supabase.auth.signOut()
            await revenueCatManager.signOut()

            // Clear local state
            profile = nil

            // Post notification to update the UI
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)

        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            isDeletingAccount = false
            return
        }

        isDeletingAccount = false
    }
    
    // MARK: - Subscription Timer
    
    private func startSubscriptionTimer(from startDate: Date) {
        updateElapsedTime(from: startDate)
        
        subscriptionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateElapsedTime(from: startDate)
        }
    }
    
    private func updateElapsedTime(from startDate: Date) {
        let now = Date()
        let components = Calendar.current.dateComponents([.month, .day, .hour, .minute, .second], from: startDate, to: now)
        
        let months = components.month ?? 0
        let days = components.day ?? 0
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let seconds = components.second ?? 0
        
        // Format: MM:DD:HH:MM:SS
        elapsedTime = String(format: "%02d:%02d:%02d:%02d:%02d", months, days, hours, minutes, seconds)
    }
}

// MARK: - Level Progress View
struct LevelProgressView: View {
    let subscriptionDate: Date
    
    // Level thresholds in days
    private let levelThresholds: [Int] = [0, 30, 90, 180, 365, 730] // Level 1-6+
    private let levelNames: [String] = ["Newcomer", "Explorer", "Dedicated", "Committed", "Veteran", "Legend"]
    
    private var daysSinceSubscription: Int {
        Calendar.current.dateComponents([.day], from: subscriptionDate, to: Date()).day ?? 0
    }
    
    private var currentLevel: Int {
        for (index, threshold) in levelThresholds.enumerated().reversed() {
            if daysSinceSubscription >= threshold {
                return index + 1
            }
        }
        return 1
    }
    
    private var currentLevelName: String {
        let index = min(currentLevel - 1, levelNames.count - 1)
        return levelNames[index]
    }
    
    private var nextLevelThreshold: Int {
        if currentLevel < levelThresholds.count {
            return levelThresholds[currentLevel]
        }
        return levelThresholds.last ?? 730
    }
    
    private var currentLevelThreshold: Int {
        return levelThresholds[currentLevel - 1]
    }
    
    private var progress: Double {
        if currentLevel >= levelThresholds.count {
            return 1.0 // Max level reached
        }
        let daysInCurrentLevel = daysSinceSubscription - currentLevelThreshold
        let daysNeededForNextLevel = nextLevelThreshold - currentLevelThreshold
        return min(1.0, Double(daysInCurrentLevel) / Double(daysNeededForNextLevel))
    }
    
    private var daysUntilNextLevel: Int {
        return max(0, nextLevelThreshold - daysSinceSubscription)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Level Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LEVEL \(currentLevel)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(1.5)
                        .foregroundColor(.secondary)
                    
                    Text(currentLevelName)
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if currentLevel < levelThresholds.count {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("NEXT LEVEL")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("\(daysUntilNextLevel) days")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                } else {
                    Text("MAX LEVEL")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 16)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary)
                        .frame(width: geometry.size.width * progress, height: 16)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 16)
            
            // Progress Labels
            HStack {
                Text("Level \(currentLevel)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if currentLevel < levelThresholds.count {
                    Text("Level \(currentLevel + 1)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    ProfileView()
        .environmentObject(RevenueCatManager.shared)
}
