import SwiftUI

struct InstallServerView: View {
    let server: MCPServer
    let apiService: APIService
    
    // GoHighLevel Configuration
    @State private var ghlAPIKey: String = ""
    @State private var ghlLocationID: String = ""
    @State private var ghlBaseURL: String = "https://services.leadconnectorhq.com"
    
    // Meta Ads Configuration
    @State private var metaAccessToken: String = ""
    @State private var metaAppID: String = ""
    @State private var metaAppSecret: String = ""
    
    // Google Ads Configuration
    @State private var googleAdsCustomerID: String = ""
    @State private var googleAdsDeveloperToken: String = ""
    @State private var googleAdsClientID: String = ""
    @State private var googleAdsClientSecret: String = ""
    @State private var googleAdsRefreshToken: String = ""
    
    @State private var isInstalling: Bool = false
    @State private var installationError: String?
    @State private var installationSuccess: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            InstallHeaderView(server: server, onCancel: { dismiss() })
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Server Info Card
                    ServerInfoCard(server: server)
                    
                    // Configuration Form
                    ConfigurationFormView(
                        server: server,
                        ghlAPIKey: $ghlAPIKey,
                        ghlLocationID: $ghlLocationID,
                        ghlBaseURL: $ghlBaseURL,
                        metaAccessToken: $metaAccessToken,
                        metaAppID: $metaAppID,
                        metaAppSecret: $metaAppSecret,
                        googleAdsCustomerID: $googleAdsCustomerID,
                        googleAdsDeveloperToken: $googleAdsDeveloperToken,
                        googleAdsClientID: $googleAdsClientID,
                        googleAdsClientSecret: $googleAdsClientSecret,
                        googleAdsRefreshToken: $googleAdsRefreshToken
                    )
                    
                    // Status Messages
                    StatusMessagesView(
                        error: installationError,
                        success: installationSuccess
                    )
                }
                .padding(24)
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            // Footer
            InstallFooterView(
                canInstall: canInstall,
                isInstalling: isInstalling,
                onInstall: installServer,
                onCancel: { dismiss() }
            )
        }
        .frame(width: 600, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var canInstall: Bool {
        switch server.id {
        case "gohighlevel":
            return !ghlAPIKey.isEmpty && !ghlLocationID.isEmpty && !ghlBaseURL.isEmpty
        case "meta-ads":
            return !metaAccessToken.isEmpty && !metaAppID.isEmpty && !metaAppSecret.isEmpty
        case "google-ads":
            return !googleAdsCustomerID.isEmpty && !googleAdsDeveloperToken.isEmpty && 
                   !googleAdsClientID.isEmpty && !googleAdsClientSecret.isEmpty && 
                   !googleAdsRefreshToken.isEmpty
        default:
            return true
        }
    }
    
    private func installServer() {
        isInstalling = true
        installationError = nil
        installationSuccess = false
        
        var config: [String: String] = [:]
        
        switch server.id {
        case "gohighlevel":
            config = [
                "GHL_API_KEY": ghlAPIKey,
                "GHL_LOCATION_ID": ghlLocationID,
                "GHL_BASE_URL": ghlBaseURL,
                "NODE_ENV": "production",
                "PORT": "8000"
            ]
        case "meta-ads":
            config = [
                "META_ACCESS_TOKEN": metaAccessToken,
                "META_APP_ID": metaAppID,
                "META_APP_SECRET": metaAppSecret,
                "PYTHONPATH": ".",
                "PORT": "8001"
            ]
        case "google-ads":
            config = [
                "GOOGLE_ADS_CUSTOMER_ID": googleAdsCustomerID,
                "GOOGLE_ADS_DEVELOPER_TOKEN": googleAdsDeveloperToken,
                "GOOGLE_ADS_CLIENT_ID": googleAdsClientID,
                "GOOGLE_ADS_CLIENT_SECRET": googleAdsClientSecret,
                "GOOGLE_ADS_REFRESH_TOKEN": googleAdsRefreshToken,
                "PYTHONPATH": ".",
                "PORT": "8002"
            ]
        default:
            config = [:]
        }
        
        apiService.installServer(serverID: server.id, config: config) { success, error in
            isInstalling = false
            
            if success {
                installationSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            } else {
                installationError = error ?? "Unknown error occurred"
            }
        }
    }
}

// MARK: - Install Header View
struct InstallHeaderView: View {
    let server: MCPServer
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Server Icon
                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 48, height: 48)
                    .background(iconColor.opacity(0.1))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Install \(server.name)")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Configure your credentials to get started")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
                .background(Color(NSColor.separatorColor))
        }
    }
    
    private var iconName: String {
        switch server.id {
        case "gohighlevel": return "building.2"
        case "meta-ads": return "megaphone"
        case "google-ads": return "magnifyingglass"
        default: return "server.rack"
        }
    }
    
    private var iconColor: Color {
        switch server.id {
        case "gohighlevel": return .green
        case "meta-ads": return .blue
        case "google-ads": return .purple
        default: return .gray
        }
    }
}

// MARK: - Server Info Card
struct ServerInfoCard: View {
    let server: MCPServer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Server Information")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(server.serverType ?? "Unknown")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InfoField(label: "Name", value: server.name)
                InfoField(label: "Description", value: server.description)
                InfoField(label: "Repository", value: server.repoURL)
            }
        }
        .padding(16)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

// MARK: - Info Field
struct InfoField: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Configuration Form View
struct ConfigurationFormView: View {
    let server: MCPServer
    
    @Binding var ghlAPIKey: String
    @Binding var ghlLocationID: String
    @Binding var ghlBaseURL: String
    
    @Binding var metaAccessToken: String
    @Binding var metaAppID: String
    @Binding var metaAppSecret: String
    
    @Binding var googleAdsCustomerID: String
    @Binding var googleAdsDeveloperToken: String
    @Binding var googleAdsClientID: String
    @Binding var googleAdsClientSecret: String
    @Binding var googleAdsRefreshToken: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Configuration Form
            if server.id == "gohighlevel" {
                GoHighLevelConfigView(
                    apiKey: $ghlAPIKey,
                    locationID: $ghlLocationID,
                    baseURL: $ghlBaseURL
                )
            } else if server.id == "meta-ads" {
                MetaAdsConfigView(
                    accessToken: $metaAccessToken,
                    appID: $metaAppID,
                    appSecret: $metaAppSecret
                )
            } else if server.id == "google-ads" {
                GoogleAdsConfigView(
                    customerID: $googleAdsCustomerID,
                    developerToken: $googleAdsDeveloperToken,
                    clientID: $googleAdsClientID,
                    clientSecret: $googleAdsClientSecret,
                    refreshToken: $googleAdsRefreshToken
                )
            }
            
            // Setup Guide
            SetupGuideView(serverID: server.id)
        }
    }
}

// MARK: - GoHighLevel Config View
struct GoHighLevelConfigView: View {
    @Binding var apiKey: String
    @Binding var locationID: String
    @Binding var baseURL: String
    
    var body: some View {
        ConfigSection(title: "GoHighLevel Configuration", icon: "building.2", color: .green) {
            VStack(spacing: 16) {
                FormField(
                    label: "API Key",
                    placeholder: "Enter your GHL API Key",
                    text: $apiKey,
                    isSecure: true,
                    helpText: "Private Integration API Key (not regular API key)"
                )
                
                FormField(
                    label: "Location ID",
                    placeholder: "Enter your GHL Location ID",
                    text: $locationID,
                    helpText: "Found in Settings → Company → Locations"
                )
                
                FormField(
                    label: "Base URL",
                    placeholder: "GHL Base URL",
                    text: $baseURL,
                    helpText: "Default API endpoint (usually no need to change)"
                )
            }
        }
    }
}

// MARK: - Meta Ads Config View
struct MetaAdsConfigView: View {
    @Binding var accessToken: String
    @Binding var appID: String
    @Binding var appSecret: String
    
    var body: some View {
        ConfigSection(title: "Meta Ads Configuration", icon: "megaphone", color: .blue) {
            VStack(spacing: 16) {
                FormField(
                    label: "Access Token",
                    placeholder: "Enter your Meta Access Token",
                    text: $accessToken,
                    isSecure: true,
                    helpText: "Long-lived access token from Graph API Explorer"
                )
                
                FormField(
                    label: "App ID",
                    placeholder: "Enter your Meta App ID",
                    text: $appID,
                    helpText: "App ID from your Meta for Developers app"
                )
                
                FormField(
                    label: "App Secret",
                    placeholder: "Enter your Meta App Secret",
                    text: $appSecret,
                    isSecure: true,
                    helpText: "App Secret from your Meta for Developers app"
                )
            }
        }
    }
}

// MARK: - Google Ads Config View
struct GoogleAdsConfigView: View {
    @Binding var customerID: String
    @Binding var developerToken: String
    @Binding var clientID: String
    @Binding var clientSecret: String
    @Binding var refreshToken: String
    
    var body: some View {
        ConfigSection(title: "Google Ads Configuration", icon: "magnifyingglass", color: .purple) {
            VStack(spacing: 16) {
                FormField(
                    label: "Customer ID",
                    placeholder: "Enter your Google Ads Customer ID",
                    text: $customerID,
                    helpText: "10-digit customer ID (e.g., 123-456-7890)"
                )
                
                FormField(
                    label: "Developer Token",
                    placeholder: "Enter your Developer Token",
                    text: $developerToken,
                    isSecure: true,
                    helpText: "From Google Ads → API Center"
                )
                
                FormField(
                    label: "Client ID",
                    placeholder: "Enter your OAuth2 Client ID",
                    text: $clientID,
                    helpText: "OAuth2 Client ID from Google Cloud Console"
                )
                
                FormField(
                    label: "Client Secret",
                    placeholder: "Enter your OAuth2 Client Secret",
                    text: $clientSecret,
                    isSecure: true,
                    helpText: "OAuth2 Client Secret from Google Cloud Console"
                )
                
                FormField(
                    label: "Refresh Token",
                    placeholder: "Enter your OAuth2 Refresh Token",
                    text: $refreshToken,
                    isSecure: true,
                    helpText: "From OAuth2 Playground or authentication flow"
                )
            }
        }
    }
}

// MARK: - Config Section
struct ConfigSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            content
        }
        .padding(16)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

// MARK: - Form Field
struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var helpText: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(ModernTextFieldStyle())
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(ModernTextFieldStyle())
            }
            
            if let helpText = helpText {
                Text(helpText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Modern Text Field Style
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
    }
}

// MARK: - Setup Guide View
struct SetupGuideView: View {
    let serverID: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                
                Text("How to get your credentials")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(setupSteps.enumerated()), id: \.offset) { index, step in
                    SetupStepRow(number: index + 1, text: step)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
    
    private var setupSteps: [String] {
        switch serverID {
        case "gohighlevel":
            return [
                "Go to GoHighLevel Settings → Integrations",
                "Create a Private Integration",
                "Copy the API Key (NOT the regular API key)",
                "Get Location ID from Settings → Company → Locations"
            ]
        case "meta-ads":
            return [
                "Go to Meta for Developers → Create App",
                "Select 'Business' app type",
                "Add Marketing API product",
                "Get App ID and Secret from App Settings",
                "Generate Access Token from Graph API Explorer"
            ]
        case "google-ads":
            return [
                "Go to Google Cloud Console → APIs & Services",
                "Enable Google Ads API",
                "Create OAuth2 credentials",
                "Get Developer Token from Google Ads → API Center",
                "Use OAuth2 Playground to get refresh token"
            ]
        default:
            return []
        }
    }
}

// MARK: - Setup Step Row
struct SetupStepRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor)
                .cornerRadius(10)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Status Messages View
struct StatusMessagesView: View {
    let error: String?
    let success: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            if let error = error {
                ErrorMessage(error: error)
            }
            
            if success {
                SuccessMessage()
            }
        }
    }
}

// MARK: - Error Message
struct ErrorMessage: View {
    let error: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.red)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.red)
            
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Success Message
struct SuccessMessage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.green)
                
                Text("Installation started successfully!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Claude Desktop will be automatically configured. Restart Claude Desktop after installation completes.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Install Footer View
struct InstallFooterView: View {
    let canInstall: Bool
    let isInstalling: Bool
    let onInstall: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color(NSColor.separatorColor))
            
            HStack {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: onInstall) {
                    HStack(spacing: 8) {
                        if isInstalling {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        Text(isInstalling ? "Installing..." : "Install Server")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(canInstall && !isInstalling ? Color.accentColor : Color.gray)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canInstall || isInstalling)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

#Preview {
    InstallServerView(
        server: MCPServer(
            id: "gohighlevel",
            name: "GoHighLevel MCP",
            description: "GoHighLevel CRM integration server",
            repoURL: "https://github.com/mastanley13/GoHighLevel-MCP.git",
            installPath: "",
            command: "node",
            args: ["dist/server.js"],
            env: ["NODE_ENV": "production", "PORT": "8000"],
            port: 8000,
            statusString: "not_installed",
            logs: nil,
            category: "CRM",
            toolsCount: 8,
            serverType: "node"
        ),
        apiService: APIService()
    )
} 