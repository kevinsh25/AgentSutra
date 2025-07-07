# Claude MCP Orchestrator

A **local macOS application** that acts as a single MCP server orchestrator/proxy for Claude Desktop. Enables one-click discovery, configuration, and launch of multiple MCP servers with native UI management.

## 🎯 What This Solves

Instead of configuring individual MCP servers with Claude Desktop, this orchestrator:
- **Acts as a single endpoint** for Claude Desktop (`localhost:3000`)
- **Manages multiple MCP servers** transparently as child processes
- **Provides native macOS UI** for easy server management
- **Handles installation automatically** (clone, build, configure)

## 🏗️ Architecture

```
Claude Desktop → MCP Orchestrator (localhost:3000) → Multiple MCP Servers
                      ↑
                 Native macOS UI
```

## 🚀 Quick Start

### 1. Start the Orchestrator
```bash
cd mcp_orchestrator
go build -o bin/mcp-orchestrator
./bin/mcp-orchestrator
```

### 2. Launch the macOS UI
```bash
# Open in Xcode and build/run
open mcp_orchestrator_ui/MCPOrchestratorUI.xcodeproj
```

### 3. Configure Claude Desktop
Add this to your Claude Desktop `mcp_settings.json`:
```json
{
  "mcpServers": {
    "mcp-orchestrator": {
      "command": "stdio",
      "transport": {
        "type": "websocket",
        "url": "ws://localhost:3000"
      }
    }
  }
}
```

## 📱 Native macOS UI Features

- **Server List**: View all available MCP servers and their status
- **One-Click Install**: Install GoHighLevel MCP with credential form
- **Real-time Monitoring**: Live status updates every 5 seconds
- **Process Control**: Start/stop servers with buttons
- **Connection Health**: Visual indicators for service health

## 🔧 GoHighLevel MCP Integration

1. Click "Install" button in the UI
2. Enter your credentials:
   - **Private Integration API Key** (from GHL Settings → Integrations)
   - **Location ID** (from Settings → Company → Locations)
3. App automatically handles:
   - Repository cloning
   - npm install & build
   - Environment configuration
   - Process management

## 📂 Project Structure

```
├── mcp_orchestrator/           # Go orchestrator server
│   ├── main.go                # Main application entry
│   ├── internal/
│   │   ├── mcp/               # MCP protocol implementation
│   │   ├── servers/           # Server management
│   │   └── ui/                # HTTP API for UI
│   └── README.md              # Orchestrator documentation
│
├── mcp_orchestrator_ui/       # Native macOS SwiftUI app
│   ├── MCPOrchestratorUI/     # Swift source files
│   └── README.md              # UI documentation
│
├── project_requirement.md     # Original requirements
└── project_management.md      # Project roadmap
```

## ✅ Key Benefits

1. **Single Endpoint**: Claude Desktop connects to one orchestrator
2. **Native UI**: Beautiful macOS interface for non-technical users
3. **Local Only**: No cloud dependencies, everything runs locally
4. **Extensible**: Easy to add new MCP servers
5. **Process Management**: Handles server lifecycle automatically
6. **Zero Configuration**: One-click setup for supported servers

## 🛠️ Technical Details

- **Go Backend**: HTTP/WebSocket servers for Claude Desktop integration
- **SwiftUI Frontend**: Native macOS app with real-time updates
- **Process Management**: Child process spawning and lifecycle management
- **Local Storage**: Servers installed in `~/.mcp_orchestrator/`
- **HTTP API**: RESTful endpoints for UI communication

## 📋 Requirements

- **macOS 14.0+** for the native UI
- **Go 1.21+** for the orchestrator
- **Xcode 15.0+** for building the UI
- **Node.js** for MCP server installation

This solution perfectly implements the original requirement: *"Build a native macOS application that acts as a local MCP server orchestrator for Claude Desktop."* 