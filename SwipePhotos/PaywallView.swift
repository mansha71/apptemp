//
//  PaywallView.swift
//  OneNada
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct SubscriptionPaywallView: View {
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Group {
            let _ = print("")
            let _ = print("💳 ============ SubscriptionPaywallView RENDER ============")
            let _ = print("💳 currentOffering = \(String(describing: revenueCatManager.currentOffering))")
            let _ = print("💳 offerings = \(String(describing: revenueCatManager.offerings))")
            let _ = print("💳 isLoading = \(revenueCatManager.isLoading)")
            let _ = print("💳 errorMessage = \(String(describing: revenueCatManager.errorMessage))")
            let _ = print("💳 =========================================================")
            
            if let offering = revenueCatManager.currentOffering {
                let _ = print("💳 Showing RevenueCat PaywallView with offering: \(offering.identifier)")
                PaywallView(offering: offering)
                    .onPurchaseCompleted { customerInfo in
                        // Successfully purchased - refresh subscription status
                        print("✅ Purchase completed successfully")
                        Task {
                            await revenueCatManager.checkSubscriptionStatus()
                        }
                    }
                    .onRestoreCompleted { customerInfo in
                        // Successfully restored - refresh subscription status
                        print("✅ Restore completed successfully")
                        Task {
                            await revenueCatManager.checkSubscriptionStatus()
                        }
                    }
            } else {
                // Loading state while offerings are being fetched
                let _ = print("💳 currentOffering is NIL - showing loading spinner")
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Loading subscription options...")
                        .foregroundColor(.secondary)
                    
                    // DEBUG: Show error if any
                    if let error = revenueCatManager.errorMessage {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                    }
                }
                .task {
                    print("💳 Calling loadOfferings() from SubscriptionPaywallView...")
                    await revenueCatManager.loadOfferings()
                    print("💳 loadOfferings() completed. currentOffering = \(String(describing: revenueCatManager.currentOffering))")
                }
            }
        }
    }
}

#Preview {
    SubscriptionPaywallView()
        .environmentObject(RevenueCatManager.shared)
        .environmentObject(ThemeManager.shared)
}
