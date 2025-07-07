import SwiftUI

// MARK: - View Mode
enum ViewMode: String, CaseIterable {
    case grid = "Grid"
    case list = "List"
    
    var icon: String {
        switch self {
        case .grid: return DesignSystem.Icons.grid
        case .list: return DesignSystem.Icons.list
        }
    }
}

// MARK: - Sidebar Items
enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    // Temporarily commented out problematic tabs
    // case performance = "Performance"
    // case logs = "Logs"
    // case backup = "Backup"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return DesignSystem.Icons.dashboard
        // case .performance: return DesignSystem.Icons.performance
        // case .logs: return DesignSystem.Icons.logs
        // case .backup: return DesignSystem.Icons.backup
        }
    }
    
    var color: Color {
        switch self {
        case .dashboard: return DesignSystem.Colors.primary
        // case .performance: return DesignSystem.Colors.success
        // case .logs: return DesignSystem.Colors.warning
        // case .backup: return DesignSystem.Colors.info
        }
    }
}

// MARK: - Modern Content View
struct ModernContentView: View {
    @StateObject private var apiService = APIService()
    @StateObject private var performanceMonitor = PerformanceMonitor()
    @StateObject private var loggingManager = SimpleLoggingManager.shared
    @StateObject private var backupManager = BackupManager.shared
    
    @State private var selectedSidebarItem: SidebarItem = .dashboard
    @State private var showingAddServer = false
    @State private var showingServerConfiguration = false
    @State private var selectedServer: MCPServer?
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var viewMode: ViewMode = .grid
    @State private var serverToInstall: MCPServer?
    @State private var refreshTrigger = UUID()
    
    private let categories = ["All", "Development", "Communication", "Productivity", "Data", "AI"]
    
    var filteredServers: [MCPServer] {
        var servers = apiService.servers
        
        // Filter by category
        if selectedCategory != "All" {
            servers = servers.filter { $0.category == selectedCategory }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            servers = servers.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return servers
    }
    
    var body: some View {
        HSplitView {
            // Sidebar
            sidebarView
                .frame(minWidth: DesignSystem.Layout.sidebarMinWidth, 
                       idealWidth: DesignSystem.Layout.sidebarWidth,
                       maxWidth: DesignSystem.Layout.sidebarMaxWidth)
            
            // Main Content
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content Area
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DesignSystem.Colors.surface)
        .sheet(isPresented: $showingAddServer) {
            InstallServerView(
                server: MCPServer(
                    id: "new-server", 
                    name: "New Server", 
                    description: "Configure a new MCP server", 
                    repoURL: "", 
                    installPath: "", 
                    command: "", 
                    args: [], 
                    env: [:], 
                    port: 8080, 
                    statusString: "not_installed", 
                    logs: nil, 
                    category: "General", 
                    toolsCount: 0, 
                    serverType: "node"
                ),
                apiService: apiService
            )
        }
        .sheet(isPresented: $showingServerConfiguration) {
            if let server = serverToInstall {
                ServerConfigurationView(
                    server: server,
                    onInstall: { config in
                        performInstallation(server: server, config: config)
                    },
                    onCancel: {
                        showingServerConfiguration = false
                        serverToInstall = nil
                    }
                )
            }
        }
        .onAppear {
            loadData()
        }
        .id(refreshTrigger)
    }
    
    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Sidebar Header
            VStack(spacing: DesignSystem.Spacing.lg) {
                HStack {
                    Image(systemName: "server.rack")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                    
                    Text("MCP Orchestrator")
                        .font(DesignSystem.Typography.title3)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                }
                
                // System Status
                systemStatusView
            }
            .padding(DesignSystem.Spacing.lg)
            
            Divider()
                .padding(.horizontal, DesignSystem.Spacing.sm)
            
            // Navigation Items
            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(SidebarItem.allCases) { item in
                    SidebarItemView(
                        item: item,
                        isSelected: selectedSidebarItem == item
                    ) {
                        withAnimation(DesignSystem.Animation.fast) {
                            selectedSidebarItem = item
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.md)
            
            Spacer()
            
            // Sidebar Footer
            VStack(spacing: DesignSystem.Spacing.md) {
                Divider()
                
                HStack {
                    Button(action: {
                        // TODO: Add preferences functionality
                    }) {
                        Image(systemName: DesignSystem.Icons.settings)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Preferences")
                    .disabled(true) // Temporarily disabled
                    
                    Spacer()
                    
                    Button(action: {
                        refreshData()
                    }) {
                        Image(systemName: DesignSystem.Icons.refresh)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(IconButtonStyle())
                    .help("Refresh")
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.sm)
            }
        }
        .background(DesignSystem.Colors.surfaceElevated)
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - System Status View
    private var systemStatusView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Circle()
                    .fill(systemHealthColor)
                    .frame(width: 8, height: 8)
                
                Text("System Health")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Spacer()
                
                Text(systemHealthStatus)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(systemHealthColor)
            }
            
            HStack {
                Text("\(apiService.servers.count) servers")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                
                Spacer()
                
                Text("\(onlineServersCount)/\(apiService.servers.count) online")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.Layout.cornerRadiusSmall)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                // Title and Search
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text(selectedSidebarItem.rawValue)
                        .font(DesignSystem.Typography.largeTitle)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    if selectedSidebarItem == .dashboard {
                        HStack {
                            Image(systemName: DesignSystem.Icons.search)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                            
                            TextField("Search servers...", text: $searchText)
                                .font(DesignSystem.Typography.body)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.surfaceSecondary)
                        .cornerRadius(DesignSystem.Layout.cornerRadiusSmall)
                        .frame(maxWidth: 300)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if selectedSidebarItem == .dashboard {
                        // View Mode Toggle
                        HStack(spacing: 0) {
                            ForEach(ViewMode.allCases, id: \.self) { mode in
                                Button(action: {
                                    withAnimation(DesignSystem.Animation.fast) {
                                        viewMode = mode
                                    }
                                }) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(viewMode == mode ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(DesignSystem.Spacing.sm)
                                .background(viewMode == mode ? DesignSystem.Colors.selected : Color.clear)
                                .cornerRadius(DesignSystem.Layout.cornerRadiusSmall)
                            }
                        }
                        .background(DesignSystem.Colors.surfaceSecondary)
                        .cornerRadius(DesignSystem.Layout.cornerRadiusSmall)
                        
                        // Add Server Button
                        Button(action: {
                            showingAddServer = true
                        }) {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: DesignSystem.Icons.add)
                                    .font(.system(size: 14, weight: .medium))
                                
                                Text("Add Server")
                                    .font(DesignSystem.Typography.bodyMedium)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xxl)
            .padding(.vertical, DesignSystem.Spacing.lg)
            
            // Category Filter (Dashboard only)
            if selectedSidebarItem == .dashboard {
                HStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(categories, id: \.self) { category in
                                CategoryFilterButton(
                                    title: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    withAnimation(DesignSystem.Animation.fast) {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.xxl)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            
            Divider()
        }
        .background(DesignSystem.Colors.surface)
    }
    
    // MARK: - Content View
    private var contentView: some View {
        Group {
            switch selectedSidebarItem {
            case .dashboard:
                dashboardView
            // Temporarily commented out problematic views
            // case .performance:
            //     ModernPerformanceDashboard()
            // case .logs:
            //     ModernLogViewerView()
            // case .backup:
            //     ModernBackupRestoreView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Dashboard View
    private var dashboardView: some View {
        VStack {
            if apiService.isLoading {
                LoadingView("Loading servers...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = apiService.error {
                EmptyStateView(
                    icon: DesignSystem.Icons.error,
                    title: "Error Loading Servers",
                    subtitle: error,
                    actionTitle: "Try Again"
                ) {
                    refreshData()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredServers.isEmpty {
                EmptyStateView(
                    icon: DesignSystem.Icons.server,
                    title: searchText.isEmpty ? "No Servers Configured" : "No Servers Found",
                    subtitle: searchText.isEmpty ? "Add your first MCP server to get started" : "Try adjusting your search or filter criteria",
                    actionTitle: searchText.isEmpty ? "Add Server" : nil
                ) {
                    if searchText.isEmpty {
                        showingAddServer = true
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Group {
                    if viewMode == .grid {
                        MCPGridView(servers: filteredServers) { server, action in
                            handleServerAction(server, action)
                        }
                    } else {
                        MCPListView(servers: filteredServers) { server, action in
                            handleServerAction(server, action)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DesignSystem.Colors.surface)
    }
    
    // MARK: - Helper Methods
    private func loadData() {
        apiService.loadServers()
        apiService.loadCategories()
    }
    
    private func refreshData() {
        withAnimation(DesignSystem.Animation.medium) {
            refreshTrigger = UUID()
        }
        loadData()
    }
    
    private func handleServerAction(_ server: MCPServer, _ action: MCPCardAction) {
        switch action {
        case .showDetails:
            selectedServer = server
            
        case .install:
            serverToInstall = server
            showingServerConfiguration = true
            
        case .start:
            apiService.startServer(serverID: server.id) { success, error in
                if success {
                    loggingManager.info("Started server: \(server.name)", category: .server)
                    refreshData()
                } else {
                    loggingManager.error("Failed to start server: \(error ?? "Unknown error")", category: .server)
                }
            }
            
        case .stop:
            apiService.stopServer(serverID: server.id) { success, error in
                if success {
                    loggingManager.info("Stopped server: \(server.name)", category: .server)
                    refreshData()
                } else {
                    loggingManager.error("Failed to stop server: \(error ?? "Unknown error")", category: .server)
                }
            }
            
        case .restart:
            // Implement restart logic
            break
            
        case .refresh:
            refreshData()
            
        case .settings:
            selectedServer = server
            
        case .viewLogs:
            // selectedSidebarItem = .logs  // Commented out since logs tab is disabled
            break
            
        case .remove:
            // Implement remove logic
            break
        }
    }
    
    private func performInstallation(server: MCPServer, config: [String: String]) {
        showingServerConfiguration = false
        serverToInstall = nil
        
        apiService.installServer(serverID: server.id, config: config) { success, error in
            if success {
                loggingManager.info("Installing server: \(server.name)", category: .server)
                refreshData()
            } else {
                loggingManager.error("Failed to install server: \(error ?? "Unknown error")", category: .server)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var systemHealthColor: Color {
        let onlineCount = onlineServersCount
        let totalCount = apiService.servers.count
        
        if totalCount == 0 {
            return DesignSystem.Colors.idle
        } else if onlineCount == totalCount {
            return DesignSystem.Colors.success
        } else if onlineCount > totalCount / 2 {
            return DesignSystem.Colors.warning
        } else {
            return DesignSystem.Colors.error
        }
    }
    
    private var systemHealthStatus: String {
        let onlineCount = onlineServersCount
        let totalCount = apiService.servers.count
        
        if totalCount == 0 {
            return "No servers"
        } else if onlineCount == totalCount {
            return "Healthy"
        } else if onlineCount > totalCount / 2 {
            return "Degraded"
        } else {
            return "Critical"
        }
    }
    
    private var onlineServersCount: Int {
        apiService.servers.filter { $0.isRunning && $0.health == "healthy" }.count
    }
}

// MARK: - Sidebar Item View
struct SidebarItemView: View {
    let item: SidebarItem
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? item.color : DesignSystem.Colors.textSecondary)
                    .frame(width: 20)
                
                Text(item.rawValue)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                    .fill(isSelected ? item.color.opacity(0.1) : (isHovering ? DesignSystem.Colors.hover : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                    .stroke(isSelected ? item.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(DesignSystem.Animation.fast, value: isSelected)
        .animation(DesignSystem.Animation.fast, value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Category Filter Button
struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.calloutMedium)
                .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                        .fill(isSelected ? DesignSystem.Colors.primaryLight : DesignSystem.Colors.surfaceSecondary)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct ModernContentView_Previews: PreviewProvider {
    static var previews: some View {
        ModernContentView()
            .frame(width: 1200, height: 800)
            .preferredColorScheme(.light)
    }
} 