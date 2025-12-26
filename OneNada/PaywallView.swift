//
//  PaywallView.swift
//  OneNada
//
//  Created by Samik Choudhury on 08/11/25.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct SubscriptionPaywallView: View {
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @Environment(\.dismiss) var dismiss
    
    var reservedNumber: Int?
    var reservationStartTime: Date?
    var onTimerExpired: (() -> Void)?
    
    private let reservationDuration: TimeInterval = 30 // 30 seconds
    
    @State private var remainingTime: Int = 30
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Reservation banner at top
            if let number = reservedNumber, reservationStartTime != nil {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "number.circle.fill")
                            .foregroundColor(.white)
                        Text("Reserving #\(number)")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(remainingTime)s")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 4)
                                .cornerRadius(2)
                            
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: geometry.size.width * CGFloat(remainingTime) / CGFloat(reservationDuration), height: 4)
                                .cornerRadius(2)
                                .animation(.linear(duration: 1), value: remainingTime)
                        }
                    }
                    .frame(height: 4)
                }
                .padding()
                .background(Color.orange)
            }
            
            // PaywallView content
            Group {
                if let offering = revenueCatManager.currentOffering {
                    PaywallView(offering: offering)
                        .onPurchaseCompleted { customerInfo in
                            // Stop timer on successful purchase
                            timer?.invalidate()
                            timer = nil
                            
                            print("✅ Purchase completed successfully")
                            Task {
                                await revenueCatManager.checkSubscriptionStatus()
                                await revenueCatManager.updateSubscriptionStartDate()
                                NotificationCenter.default.post(name: .subscriptionDidComplete, object: nil)
                            }
                            dismiss()
                        }
                        .onRestoreCompleted { customerInfo in
                            timer?.invalidate()
                            timer = nil
                            
                            print("✅ Restore completed successfully")
                            Task {
                                await revenueCatManager.checkSubscriptionStatus()
                            }
                            dismiss()
                        }
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Loading subscription options...")
                            .foregroundColor(.secondary)
                    }
                    .task {
                        await revenueCatManager.loadOfferings()
                    }
                }
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startTimer() {
        guard reservationStartTime != nil else { return }
        
        // Calculate remaining time based on start time
        updateRemainingTime()
        
        // Start countdown timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateRemainingTime()
            
            if remainingTime <= 0 {
                timer?.invalidate()
                timer = nil
                
                // Clear the reserved number
                revenueCatManager.reservedMemberNumber = nil
                
                // Notify that timer expired and dismiss
                onTimerExpired?()
                dismiss()
            }
        }
    }
    
    private func updateRemainingTime() {
        guard let startTime = reservationStartTime else {
            remainingTime = Int(reservationDuration)
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = max(0, Int(reservationDuration - elapsed))
        remainingTime = remaining
    }
}


#Preview {
    SubscriptionPaywallView(
        reservedNumber: 1234,
        reservationStartTime: Date()
    )
    .environmentObject(RevenueCatManager.shared)
}
