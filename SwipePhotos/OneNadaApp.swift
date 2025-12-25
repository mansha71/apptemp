import SwiftUI

@main
struct OneNadaApp: App {
    init() {
        initializeRevenueCat()
        // Initialize theme manager
        _ = ThemeManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(RevenueCatManager.shared)
                .environmentObject(ThemeManager.shared)
        }
    }
}
