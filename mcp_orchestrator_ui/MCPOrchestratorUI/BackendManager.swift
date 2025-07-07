import Foundation
import Combine

class BackendManager: ObservableObject {
    @Published var isBackendRunning = false
    @Published var backendError: String?
    
    private var backendProcess: Process?
    private let backendPath: String
    
    init() {
        // Get the path to the backend executable
        let currentPath = FileManager.default.currentDirectoryPath
        self.backendPath = currentPath.replacingOccurrences(of: "/mcp_orchestrator_ui", with: "/mcp_orchestrator/mcp-orchestrator")
    }
    
    func startBackend() {
        guard !isBackendRunning else { return }
        
        backendProcess = Process()
        backendProcess?.executableURL = URL(fileURLWithPath: backendPath)
        backendProcess?.currentDirectoryURL = URL(fileURLWithPath: backendPath.replacingOccurrences(of: "/mcp-orchestrator", with: ""))
        
        // Set up environment
        backendProcess?.environment = ProcessInfo.processInfo.environment
        
        // Redirect output to avoid blocking
        let pipe = Pipe()
        backendProcess?.standardOutput = pipe
        backendProcess?.standardError = pipe
        
        do {
            try backendProcess?.run()
            isBackendRunning = true
            backendError = nil
            
            // Wait a moment for the backend to start
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.checkBackendHealth()
            }
            
        } catch {
            backendError = "Failed to start backend: \(error.localizedDescription)"
            isBackendRunning = false
        }
    }
    
    func stopBackend() {
        guard let process = backendProcess, process.isRunning else { return }
        
        process.terminate()
        process.waitUntilExit()
        
        isBackendRunning = false
        backendProcess = nil
    }
    
    private func checkBackendHealth() {
        guard let url = URL(string: "http://localhost:8080/health") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self?.isBackendRunning = true
                    self?.backendError = nil
                } else {
                    self?.isBackendRunning = false
                    self?.backendError = "Backend not responding"
                }
            }
        }.resume()
    }
    
    deinit {
        stopBackend()
    }
} 