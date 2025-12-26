//
//  MemberNumberReservationView.swift
//  OneNada
//

import SwiftUI
import Supabase

struct MemberNumberReservationView: View {
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @Binding var showPaywall: Bool
    @Binding var reservedNumber: Int?
    @Binding var reservationStartTime: Date?
    
    @State private var inputText: String = ""
    @State private var isChecking: Bool = false
    @State private var isAvailable: Bool? = nil
    @State private var errorMessage: String? = nil
    @State private var checkTask: Task<Void, Never>? = nil
    
    private let minNumber = 1
    private let maxNumber = 10000
    
    var body: some View {
        VStack(spacing: 30) {
            // Sign out button in top-right corner
            HStack {
                Spacer()
                Button(action: {
                    Task {
                        try? await supabase.auth.signOut()
                        await revenueCatManager.signOut()
                        NotificationCenter.default.post(name: .userDidSignOut, object: nil)
                    }
                }) {
                    Text("Sign Out")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Title
            VStack(spacing: 12) {
                Text("Choose Your Number")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Pick a membership number between 1 and 10,000")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Number Input
            VStack(spacing: 16) {
                HStack {
                    Text("#")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.primary)
                    
                    TextField("", text: $inputText)
                        .font(.system(size: 48, weight: .bold))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 200)
                        .onChange(of: inputText) { oldValue, newValue in
                            // Filter to only allow digits
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                inputText = filtered
                            }
                            
                            // Limit to 5 characters (max 10000)
                            if filtered.count > 5 {
                                inputText = String(filtered.prefix(5))
                            }
                            
                            // Reset availability when input changes
                            isAvailable = nil
                            errorMessage = nil
                            
                            // Debounce the availability check
                            checkTask?.cancel()
                            checkTask = Task {
                                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
                                if !Task.isCancelled {
                                    await checkAvailability()
                                }
                            }
                        }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 2)
                )
                
                // Status text
                if isChecking {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Checking availability...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                } else if isAvailable == true {
                    Text("This number is available!")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Reserve Button
            Button(action: reserveNumber) {
                Text("Reserve Number")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isAvailable == true ? Color.primary : Color.gray.opacity(0.3))
                    .foregroundColor(isAvailable == true ? Color(.systemBackground) : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(isAvailable != true)
        }
        .padding()
    }
    
    private var borderColor: Color {
        if isAvailable == true {
            return .green
        } else if errorMessage != nil {
            return .red
        } else {
            return Color(.systemGray4)
        }
    }
    
    private func checkAvailability() async {
        guard let number = Int(inputText) else {
            await MainActor.run {
                isAvailable = nil
                errorMessage = nil
            }
            return
        }
        
        // Validate range
        guard number >= minNumber && number <= maxNumber else {
            await MainActor.run {
                isAvailable = false
                errorMessage = "Please enter a number between 1 and 10,000"
            }
            return
        }
        
        await MainActor.run {
            isChecking = true
        }
        
        do {
            // Query the member_number_pool table to check if number is available
            let response: [MemberNumberPoolEntry] = try await supabase
                .from("member_number_pool")
                .select()
                .eq("member_number", value: number)
                .execute()
                .value
            
            await MainActor.run {
                isChecking = false
                
                if let entry = response.first {
                    if entry.isAvailable {
                        isAvailable = true
                        errorMessage = nil
                    } else {
                        isAvailable = false
                        errorMessage = "This number is already taken"
                    }
                } else {
                    // Number not in pool (shouldn't happen if pool is seeded 1-10000)
                    isAvailable = false
                    errorMessage = "Invalid number"
                }
            }
        } catch {
            await MainActor.run {
                isChecking = false
                isAvailable = false
                errorMessage = "Failed to check availability"
            }
            print("❌ Error checking availability: \(error)")
        }
    }
    
    private func reserveNumber() {
        guard let number = Int(inputText), isAvailable == true else { return }
        
        // Set the reserved number and start time
        reservedNumber = number
        reservationStartTime = Date()
        
        // Store in RevenueCatManager for use during subscription
        revenueCatManager.reservedMemberNumber = number
        
        // Show paywall
        showPaywall = true
    }
}

// Model for decoding member_number_pool entries
struct MemberNumberPoolEntry: Codable {
    let memberNumber: Int
    let isAvailable: Bool
    let assignedTo: String?
    let assignedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case memberNumber = "member_number"
        case isAvailable = "is_available"
        case assignedTo = "assigned_to"
        case assignedAt = "assigned_at"
    }
}

#Preview {
    MemberNumberReservationView(
        showPaywall: .constant(false),
        reservedNumber: .constant(nil),
        reservationStartTime: .constant(nil)
    )
    .environmentObject(RevenueCatManager.shared)
}
