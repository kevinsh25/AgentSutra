import Foundation
import Combine

class APIService: ObservableObject {
    private let baseURL = "http://localhost:8080"
    private let session = URLSession.shared
    
    @Published var servers: [MCPServer] = []
    @Published var categories: [ServerCategory] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isConnected = false
    
    private var pollingTimer: Timer?
    
    func loadServers() {
        isLoading = true
        error = nil
        
        guard let url = URL(string: "\(baseURL)/api/servers") else {
            error = "Invalid URL"
            isLoading = false
            return
        }
        
        session.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self?.error = "No data received"
                    return
                }
                
                do {
                    let serverResponse = try JSONDecoder().decode(ServerListResponse.self, from: data)
                    self?.servers = serverResponse.servers
                } catch {
                    self?.error = "Failed to decode response: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func loadCategories() {
        guard let url = URL(string: "\(baseURL)/api/categories") else {
            error = "Invalid URL"
            return
        }
        
        session.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self?.error = "No data received"
                    return
                }
                
                do {
                    let categoriesResponse = try JSONDecoder().decode(CategoriesResponse.self, from: data)
                    self?.categories = categoriesResponse.categories
                } catch {
                    self?.error = "Failed to decode categories: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func installServer(serverID: String, config: [String: String], completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/servers/install") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let installRequest = InstallRequest(serverID: serverID, config: config)
        
        do {
            let jsonData = try JSONEncoder().encode(installRequest)
            request.httpBody = jsonData
        } catch {
            completion(false, "Failed to encode request: \(error.localizedDescription)")
            return
        }
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        completion(true, nil)
                    } else {
                        completion(false, "Server returned error: \(httpResponse.statusCode)")
                    }
                } else {
                    completion(false, "Invalid response")
                }
            }
        }.resume()
    }
    
    func startServer(serverID: String, completion: @escaping (Bool, String?) -> Void) {
        performServerAction(serverID: serverID, action: "start", completion: completion)
    }
    
    func stopServer(serverID: String, completion: @escaping (Bool, String?) -> Void) {
        performServerAction(serverID: serverID, action: "stop", completion: completion)
    }
    
    private func performServerAction(serverID: String, action: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/servers/\(serverID)/\(action)") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        completion(true, nil)
                    } else {
                        completion(false, "Server returned error: \(httpResponse.statusCode)")
                    }
                } else {
                    completion(false, "Invalid response")
                }
            }
        }.resume()
    }
    
    func checkOrchestratorStatus(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/health") else {
            completion(false)
            return
        }
        
        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    completion(httpResponse.statusCode == 200)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    func startPolling() {
        // Check connection status initially
        checkConnection()
        
        // Start polling every 30 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.checkConnection()
            if self.isConnected {
                self.loadServers()
            }
        }
    }
    
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    private func checkConnection() {
        checkOrchestratorStatus { connected in
            self.isConnected = connected
        }
    }
} 