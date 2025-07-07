import SwiftUI

@main
struct MCPOrchestratorUIApp: App {
    var body: some Scene {
        WindowGroup {
            ModernContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
} 