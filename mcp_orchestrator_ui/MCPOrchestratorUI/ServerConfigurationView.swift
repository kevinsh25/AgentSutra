import SwiftUI

struct ServerConfigurationView: View {
    let server: MCPServer
    let onInstall: ([String: String]) -> Void
    let onCancel: () -> Void
    
    @State private var config: [String: String] = [:]
    @State private var isInstalling = false
    @State private var showingHelp = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header
            VStack(spacing: DesignSystem.Spacing.md) {
                // Server Icon
                ZStack {
                    Circle()
                        .fill(server.statusColor == "gray" ? DesignSystem.Colors.idle.opacity(0.1) : DesignSystem.Colors.warning.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: server.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(server.statusColor == "gray" ? DesignSystem.Colors.idle : DesignSystem.Colors.warning)
                }
                
                Text("Configure \(server.name)")
                    .font(DesignSystem.Typography.headlineMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Enter the required credentials to install this server")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Configuration Fields
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(getRequiredFields(), id: \.key) { field in
                        ConfigurationFieldView(
                            field: field,
                            value: Binding(
                                get: { config[field.key] ?? "" },
                                set: { config[field.key] = $0 }
                            )
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
            .frame(maxHeight: 400)
            
            // Help Section
            if !getHelpText().isEmpty {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Button(action: {
                        showingHelp.toggle()
                    }) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 14))
                            Text("How to get these credentials")
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundColor(DesignSystem.Colors.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if showingHelp {
                        Text(getHelpText())
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                                    .fill(DesignSystem.Colors.surfaceSecondary)
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .animation(DesignSystem.Animation.fast, value: showingHelp)
            }
            
            // Action Buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isInstalling)
                
                Button(isInstalling ? "Installing..." : "Install Server") {
                    isInstalling = true
                    onInstall(config)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isInstalling || !isConfigurationValid())
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(width: 500)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.Layout.cornerRadius)
        .shadow(
            color: Color.black.opacity(DesignSystem.Layout.shadowOpacity),
            radius: DesignSystem.Layout.shadowRadius,
            x: 0,
            y: 4
        )
    }
    
    private func getRequiredFields() -> [ConfigurationField] {
        switch server.id {
        case "gohighlevel":
            return [
                ConfigurationField(
                    key: "GHL_API_KEY",
                    label: "GoHighLevel API Key",
                    placeholder: "Enter your GHL API key",
                    isSecure: true,
                    isRequired: true
                ),
                ConfigurationField(
                    key: "GHL_LOCATION_ID", 
                    label: "Location ID",
                    placeholder: "Enter your GHL location ID",
                    isSecure: false,
                    isRequired: true
                )
            ]
        case "github":
            return [
                ConfigurationField(
                    key: "GITHUB_PERSONAL_ACCESS_TOKEN",
                    label: "GitHub Personal Access Token",
                    placeholder: "ghp_xxxxxxxxxxxxxxxxxxxx",
                    isSecure: true,
                    isRequired: true
                )
            ]
        case "slack":
            return [
                ConfigurationField(
                    key: "SLACK_BOT_TOKEN",
                    label: "Slack Bot Token",
                    placeholder: "xoxb-xxxxxxxxxxxx-xxxxxxxxxxxx",
                    isSecure: true,
                    isRequired: true
                ),
                ConfigurationField(
                    key: "SLACK_SIGNING_SECRET",
                    label: "Slack Signing Secret",
                    placeholder: "Enter your Slack signing secret",
                    isSecure: true,
                    isRequired: true
                )
            ]
        case "notion":
            return [
                ConfigurationField(
                    key: "NOTION_API_KEY",
                    label: "Notion Integration Token",
                    placeholder: "secret_xxxxxxxxxxxxxxxxxxxx",
                    isSecure: true,
                    isRequired: true
                )
            ]
        case "gmail":
            return [
                ConfigurationField(
                    key: "GMAIL_CLIENT_ID",
                    label: "Gmail Client ID",
                    placeholder: "Enter your Gmail OAuth client ID",
                    isSecure: false,
                    isRequired: true
                ),
                ConfigurationField(
                    key: "GMAIL_CLIENT_SECRET",
                    label: "Gmail Client Secret",
                    placeholder: "Enter your Gmail OAuth client secret",
                    isSecure: true,
                    isRequired: true
                ),
                ConfigurationField(
                    key: "GMAIL_REFRESH_TOKEN",
                    label: "Gmail Refresh Token",
                    placeholder: "Enter your Gmail OAuth refresh token",
                    isSecure: true,
                    isRequired: true
                )
            ]
        case "google-maps":
            return [
                ConfigurationField(
                    key: "GOOGLE_MAPS_API_KEY",
                    label: "Google Maps API Key",
                    placeholder: "Enter your Google Maps API key",
                    isSecure: true,
                    isRequired: true
                )
            ]
        case "stripe":
            return [
                ConfigurationField(
                    key: "STRIPE_SECRET_KEY",
                    label: "Stripe Secret Key",
                    placeholder: "sk_test_xxxxxxxxxxxxxxxxxxxx",
                    isSecure: true,
                    isRequired: true
                )
            ]
        case "brave-search":
            return [
                ConfigurationField(
                    key: "BRAVE_API_KEY",
                    label: "Brave Search API Key",
                    placeholder: "Enter your Brave Search API key",
                    isSecure: true,
                    isRequired: true
                )
            ]
        case "meta-ads":
            return [
                ConfigurationField(
                    key: "META_ACCESS_TOKEN",
                    label: "Meta Access Token",
                    placeholder: "Enter your Meta Ads access token",
                    isSecure: true,
                    isRequired: true
                ),
                ConfigurationField(
                    key: "META_APP_ID",
                    label: "Meta App ID",
                    placeholder: "Enter your Meta app ID",
                    isSecure: false,
                    isRequired: true
                )
            ]
        case "google-ads":
            return [
                ConfigurationField(
                    key: "GOOGLE_ADS_CLIENT_ID",
                    label: "Google Ads Client ID",
                    placeholder: "Enter your Google Ads client ID",
                    isSecure: false,
                    isRequired: true
                ),
                ConfigurationField(
                    key: "GOOGLE_ADS_CLIENT_SECRET",
                    label: "Google Ads Client Secret",
                    placeholder: "Enter your Google Ads client secret",
                    isSecure: true,
                    isRequired: true
                ),
                ConfigurationField(
                    key: "GOOGLE_ADS_REFRESH_TOKEN",
                    label: "Google Ads Refresh Token",
                    placeholder: "Enter your Google Ads refresh token",
                    isSecure: true,
                    isRequired: true
                )
            ]
        default:
            // Servers that don't require configuration
            return []
        }
    }
    
    private func getHelpText() -> String {
        switch server.id {
        case "gohighlevel":
            return """
            1. Log in to your GoHighLevel account
            2. Go to Settings → Integrations → API
            3. Create a new API key
            4. Copy the API key and your location ID
            """
        case "github":
            return """
            1. Go to GitHub Settings → Developer settings → Personal access tokens
            2. Generate new token (classic)
            3. Select scopes: repo, read:user, read:org
            4. Copy the generated token
            """
        case "slack":
            return """
            1. Go to api.slack.com/apps
            2. Create a new Slack app
            3. Add bot token scopes: channels:read, chat:write, users:read
            4. Install app to workspace
            5. Copy Bot User OAuth Token and Signing Secret
            """
        case "notion":
            return """
            1. Go to notion.so/my-integrations
            2. Create a new integration
            3. Copy the Internal Integration Token
            4. Share your pages/databases with the integration
            """
        case "gmail":
            return """
            1. Go to Google Cloud Console
            2. Create OAuth 2.0 credentials
            3. Enable Gmail API
            4. Generate refresh token using OAuth playground
            """
        case "google-maps":
            return """
            1. Go to Google Cloud Console
            2. Enable Maps JavaScript API
            3. Create API key
            4. Restrict key to Maps APIs
            """
        case "stripe":
            return """
            1. Go to Stripe Dashboard
            2. Navigate to Developers → API keys
            3. Copy your Secret key (sk_test_... or sk_live_...)
            """
        case "brave-search":
            return """
            1. Go to brave.com/search/api
            2. Sign up for Brave Search API
            3. Create an API key
            4. Copy the generated key
            """
        default:
            return ""
        }
    }
    
    private func isConfigurationValid() -> Bool {
        let requiredFields = getRequiredFields()
        
        // If no fields are required, configuration is valid
        if requiredFields.isEmpty {
            return true
        }
        
        // Check that all required fields are filled
        for field in requiredFields where field.isRequired {
            if config[field.key]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                return false
            }
        }
        
        return true
    }
}

struct ConfigurationField {
    let key: String
    let label: String
    let placeholder: String
    let isSecure: Bool
    let isRequired: Bool
}

struct ConfigurationFieldView: View {
    let field: ConfigurationField
    @Binding var value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(field.label)
                    .font(DesignSystem.Typography.calloutMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                if field.isRequired {
                    Text("*")
                        .font(DesignSystem.Typography.calloutMedium)
                        .foregroundColor(DesignSystem.Colors.error)
                }
                
                Spacer()
            }
            
            Group {
                if field.isSecure {
                    SecureField(field.placeholder, text: $value)
                } else {
                    TextField(field.placeholder, text: $value)
                }
            }
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(DesignSystem.Typography.bodyMedium)
        }
    }
}

// Preview
struct ServerConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        ServerConfigurationView(
            server: MCPServer(
                id: "gohighlevel",
                name: "GoHighLevel MCP",
                description: "Test server",
                repoURL: "",
                installPath: "",
                command: "",
                args: [],
                env: [:],
                port: 8000,
                statusString: "not_installed",
                logs: nil,
                category: "crm",
                toolsCount: 253,
                serverType: "nodejs"
            ),
            onInstall: { _ in },
            onCancel: { }
        )
        .frame(width: 600, height: 800)
    }
} 