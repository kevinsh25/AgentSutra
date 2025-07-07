import SwiftUI

struct MCPCardView: View {
    let server: MCPServer
    let onAction: (MCPCardAction) -> Void
    
    @State private var isHovering = false
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header Section
            HStack {
                // Server Icon
                serverIcon
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    // Server Name
                    Text(server.name)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    
                    // Server Category
                    Text(server.category)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Status Badge
                StatusBadge(server.status, showText: false)
            }
            
            // Stats Section
            HStack(spacing: DesignSystem.Spacing.lg) {
                statItem(icon: "link", value: "\(server.toolCount)", label: "Tools")
                statItem(icon: "clock", value: server.responseTime, label: "Response")
                statItem(icon: "arrow.up.arrow.down", value: server.uptime, label: "Uptime")
            }
            .opacity(0.8)
            
            // Action Buttons (shown on hover)
            if isHovering {
                actionButtons
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .frame(minWidth: DesignSystem.Layout.cardMinWidth, maxWidth: DesignSystem.Layout.cardMaxWidth)
        .frame(height: DesignSystem.Layout.cardHeight)
        .background(cardBackground)
        .overlay(cardBorder)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(DesignSystem.Animation.spring, value: isHovering)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.fast) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onAction(.showDetails)
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    // MARK: - Subviews
    
    private var serverIcon: some View {
        ZStack {
            Circle()
                .fill(server.status.color.opacity(0.1))
                .frame(width: 40, height: 40)
            
            Image(systemName: server.iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(server.status.color)
        }
    }
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                
                Text(value)
                    .font(DesignSystem.Typography.footnoteMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.buttonSpacing) {
            // Install/Start/Stop Button
            if server.statusString == "not_installed" {
                Button(action: {
                    onAction(.install)
                }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 14, weight: .medium))
                        Text("Install")
                            .font(DesignSystem.Typography.caption)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .help("Install Server")
            } else {
                Button(action: {
                    if server.isRunning {
                        onAction(.stop)
                    } else {
                        onAction(.start)
                    }
                }) {
                    Image(systemName: server.isRunning ? DesignSystem.Icons.pause : DesignSystem.Icons.play)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(IconButtonStyle())
                .help(server.isRunning ? "Stop Server" : "Start Server")
            }
            
            // Refresh Button
            Button(action: {
                onAction(.refresh)
            }) {
                Image(systemName: DesignSystem.Icons.refresh)
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(IconButtonStyle())
            .help("Refresh Server")
            
            // Settings Button
            Button(action: {
                onAction(.settings)
            }) {
                Image(systemName: DesignSystem.Icons.settings)
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(IconButtonStyle())
            .help("Server Settings")
            
            Spacer()
            
            // More Actions
            Button(action: {
                onAction(.showDetails)
            }) {
                Image(systemName: DesignSystem.Icons.info)
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(IconButtonStyle())
            .help("View Details")
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
            .fill(DesignSystem.Colors.surface)
            .shadow(
                color: Color.black.opacity(isHovering ? DesignSystem.Layout.shadowOpacity * 2 : DesignSystem.Layout.shadowOpacity),
                radius: isHovering ? DesignSystem.Layout.shadowRadius * 1.5 : DesignSystem.Layout.shadowRadius,
                x: 0,
                y: isHovering ? 4 : 2
            )
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
            .stroke(
                server.status == .online ? DesignSystem.Colors.success.opacity(0.3) : DesignSystem.Colors.border,
                lineWidth: server.status == .online ? 2 : DesignSystem.Layout.borderWidth
            )
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button("View Details") {
            onAction(.showDetails)
        }
        
        Divider()
        
        if server.statusString == "not_installed" {
            Button("Install Server") {
                onAction(.install)
            }
            
            Divider()
        } else {
            if server.isRunning {
                Button("Stop Server") {
                    onAction(.stop)
                }
            } else {
                Button("Start Server") {
                    onAction(.start)
                }
            }
            
            Button("Restart Server") {
                onAction(.restart)
            }
            
            Divider()
        }
        
        Button("Refresh") {
            onAction(.refresh)
        }
        
        Button("Settings") {
            onAction(.settings)
        }
        
        if server.statusString != "not_installed" {
            Button("View Logs") {
                onAction(.viewLogs)
            }
        }
        
        Divider()
        
        Button("Remove Server") {
            onAction(.remove)
        }
    }
}

// MARK: - MCP Card Actions
enum MCPCardAction {
    case showDetails
    case install
    case start
    case stop
    case restart
    case refresh
    case settings
    case viewLogs
    case remove
}

// MARK: - MCP Server Extension
extension MCPServer {
    var status: MCPStatus {
        if !isRunning {
            return .offline
        }
        
        if health == "healthy" {
            return .online
        } else if health == "degraded" {
            return .warning
        } else {
            return .error
        }
    }
    

    
    var toolCount: Int {
        return tools?.count ?? 0
    }
    
    var responseTime: String {
        // Mock response time - in real implementation this would come from performance metrics
        return "245ms"
    }
    
    var uptime: String {
        // Mock uptime - in real implementation this would be calculated from start time
        return "99.9%"
    }
}

// MARK: - Grid Layout
struct MCPGridView: View {
    let servers: [MCPServer]
    let onAction: (MCPServer, MCPCardAction) -> Void
    
    private let columns = [
        GridItem(.adaptive(minimum: DesignSystem.Layout.cardMinWidth, maximum: DesignSystem.Layout.cardMaxWidth), spacing: DesignSystem.Spacing.itemSpacing)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.itemSpacing) {
                ForEach(servers, id: \.id) { server in
                    MCPCardView(server: server) { action in
                        onAction(server, action)
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }
}

// MARK: - List Layout
struct MCPListView: View {
    let servers: [MCPServer]
    let onAction: (MCPServer, MCPCardAction) -> Void
    
    var body: some View {
        List(servers, id: \.id) { server in
            MCPListRowView(server: server) { action in
                onAction(server, action)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - List Row View
struct MCPListRowView: View {
    let server: MCPServer
    let onAction: (MCPCardAction) -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Server Icon
            ZStack {
                Circle()
                    .fill(server.status.color.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: server.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(server.status.color)
            }
            
            // Server Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Text(server.name)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    StatusBadge(server.status)
                }
                
                HStack(spacing: DesignSystem.Spacing.md) {
                    Text(server.category)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text("•")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    
                    Text("\(server.toolCount) tools")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text("•")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    
                    Text(server.responseTime)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                }
            }
            
            // Action Buttons
            if isHovering {
                HStack(spacing: DesignSystem.Spacing.buttonSpacing) {
                    Button(action: {
                        if server.isRunning {
                            onAction(.stop)
                        } else {
                            onAction(.start)
                        }
                    }) {
                        Image(systemName: server.isRunning ? DesignSystem.Icons.pause : DesignSystem.Icons.play)
                    }
                    .buttonStyle(IconButtonStyle())
                    
                    Button(action: {
                        onAction(.settings)
                    }) {
                        Image(systemName: DesignSystem.Icons.settings)
                    }
                    .buttonStyle(IconButtonStyle())
                    
                    Button(action: {
                        onAction(.showDetails)
                    }) {
                        Image(systemName: DesignSystem.Icons.info)
                    }
                    .buttonStyle(IconButtonStyle())
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                .fill(isHovering ? DesignSystem.Colors.hover : Color.clear)
        )
        .animation(DesignSystem.Animation.fast, value: isHovering)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.fast) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onAction(.showDetails)
        }
    }
}

// MARK: - Preview
struct MCPCardView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleServer = MCPServer(
            id: "github-server",
            name: "GitHub Integration",
            description: "GitHub API integration server",
            repoURL: "https://github.com/example/github-mcp",
            installPath: "/usr/local/bin/github-mcp",
            command: "node",
            args: ["index.js"],
            env: [:],
            port: 8080,
            statusString: "running",
            logs: nil,
            category: "Development",
            toolsCount: 5,
            serverType: "node"
        )
        
        VStack(spacing: 20) {
            MCPCardView(server: sampleServer) { action in
                print("Action: \(action)")
            }
            
            MCPListRowView(server: sampleServer) { action in
                print("Action: \(action)")
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(.light)
    }
} 