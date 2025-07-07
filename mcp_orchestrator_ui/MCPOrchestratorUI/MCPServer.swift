import Foundation

struct MCPServer: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let repoURL: String
    let installPath: String
    let command: String
    let args: [String]
    let env: [String: String]
    let port: Int
    let statusString: String
    let logs: [String]?
    let category: String
    let toolsCount: Int?
    let serverType: String?
    
    var isRunning: Bool {
        return statusString == "running"
    }
    
    var health: String {
        switch statusString {
        case "running":
            return "healthy"
        case "stopped":
            return "stopped"
        case "installing":
            return "degraded"
        case "failed":
            return "unhealthy"
        default:
            return "unknown"
        }
    }
    
    var tools: [String]? {
        return Array(0..<(toolsCount ?? 0)).map { "Tool \($0 + 1)" }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, command, args, env, port, logs, category
        case repoURL = "repo_url"
        case installPath = "install_path"
        case toolsCount = "tools_count"
        case serverType = "server_type"
        case statusString = "status"
    }
    
    var statusColor: String {
        switch statusString {
        case "running":
            return "green"
        case "stopped":
            return "red"
        case "installing":
            return "orange"
        case "installed":
            return "blue"
        case "not_installed":
            return "gray"
        case "failed":
            return "red"
        default:
            return "gray"
        }
    }
    
    var isInstalled: Bool {
        return statusString != "not_installed"
    }
    
    var canStart: Bool {
        return statusString == "installed" || statusString == "stopped"
    }
    
    var canStop: Bool {
        return statusString == "running"
    }
    
    var iconName: String {
        switch category.lowercased() {
        case "crm":
            return "person.3.fill"
        case "advertising":
            return "megaphone.fill"
        case "design":
            return "paintbrush.fill"
        case "development":
            return "hammer.fill"
        case "communication":
            return "message.fill"
        case "productivity":
            return "doc.text.fill"
        case "ecommerce":
            return "cart.fill"
        case "maps":
            return "map.fill"
        case "web_browser":
            return "globe"
        case "email":
            return "envelope.fill"
        case "cloud":
            return "cloud.fill"
        default:
            return "server.rack"
        }
    }
}

struct ServerCategory: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let serverCount: Int
    let toolsCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon
        case serverCount = "server_count"
        case toolsCount = "tools_count"
    }
}

struct ServerListResponse: Codable {
    let servers: [MCPServer]
}

struct CategoriesResponse: Codable {
    let categories: [ServerCategory]
}

struct InstallRequest: Codable {
    let serverID: String
    let config: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case serverID = "server_id"
        case config
    }
} 