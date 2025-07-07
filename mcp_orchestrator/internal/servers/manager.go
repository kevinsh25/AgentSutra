package servers

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	"mcp_orchestrator/internal/mcp"
)

// ServerConfig represents configuration for an MCP server
type ServerConfig struct {
	ID          string            `json:"id"`
	Name        string            `json:"name"`
	Description string            `json:"description"`
	RepoURL     string            `json:"repo_url"`
	InstallPath string            `json:"install_path"`
	Command     string            `json:"command"`
	Args        []string          `json:"args"`
	Env         map[string]string `json:"env"`
	Port        int               `json:"port"`
	Status      string            `json:"status"`
	Process     *os.Process       `json:"-"`
	Logs        []string          `json:"logs"`
	ServerType  string            `json:"server_type"` // "nodejs" or "python"
	Category    string            `json:"category"`    // Server category for UI organization
	ToolsCount  int               `json:"tools_count"` // Number of tools provided by the server
	SubPath     string            `json:"sub_path"`    // Subdirectory within the repository
}

// ClaudeDesktopConfig represents the Claude Desktop configuration structure
type ClaudeDesktopConfig struct {
	MCPServers map[string]MCPServerConfig `json:"mcpServers"`
}

// MCPServerConfig represents individual MCP server configuration for Claude Desktop
type MCPServerConfig struct {
	// For stdio transport
	Command string   `json:"command,omitempty"`
	Args    []string `json:"args,omitempty"`

	// For websocket transport
	Transport *TransportConfig `json:"transport,omitempty"`
}

// TransportConfig represents the transport configuration
type TransportConfig struct {
	Type string `json:"type"`
	URL  string `json:"url"`
}

// Manager handles MCP server lifecycle
type Manager struct {
	orchestrator *mcp.Orchestrator
	servers      map[string]*ServerConfig
	mu           sync.RWMutex
	basePath     string
	validator    *ConfigValidator
	errors       map[string][]*EnhancedError // serverID -> errors
	errorsMu     sync.RWMutex
}

// NewManager creates a new server manager
func NewManager(orchestrator *mcp.Orchestrator) *Manager {
	homeDir, _ := os.UserHomeDir()
	basePath := filepath.Join(homeDir, ".mcp_orchestrator")

	// Create base directory if it doesn't exist
	os.MkdirAll(basePath, 0755)

	manager := &Manager{
		orchestrator: orchestrator,
		servers:      make(map[string]*ServerConfig),
		basePath:     basePath,
		validator:    NewConfigValidator(basePath),
		errors:       make(map[string][]*EnhancedError),
	}

	// Load existing server installations on startup
	if err := manager.loadServerState(); err != nil {
		log.Printf("Warning: Failed to load server state: %v", err)
	}

	return manager
}

// GetAvailableServers returns predefined server configurations
func (m *Manager) GetAvailableServers() []*ServerConfig {
	return []*ServerConfig{
		// Existing servers
		{
			ID:          "gohighlevel",
			Name:        "GoHighLevel MCP",
			Description: "Customer relationship management and marketing automation platform with 253 tools for lead generation, nurturing, and sales process automation",
			RepoURL:     "https://github.com/mastanley13/GoHighLevel-MCP.git",
			Command:     "node",
			Args:        []string{"dist/server.js"},
			Port:        8000,
			Status:      "not_installed",
			Env: map[string]string{
				"NODE_ENV": "production",
				"PORT":     "8000",
			},
			ServerType: "nodejs",
			Category:   "crm",
			ToolsCount: 253,
		},
		{
			ID:          "meta-ads",
			Name:        "Meta Ads MCP",
			Description: "Facebook and Instagram advertising platform with 22 tools for campaign management, audience targeting, and performance analytics",
			RepoURL:     "https://github.com/pipeboard-co/meta-ads-mcp.git",
			Command:     "python",
			Args:        []string{"-m", "meta_ads_mcp"},
			Port:        8001,
			Status:      "not_installed",
			Env: map[string]string{
				"PYTHONPATH": ".",
			},
			ServerType: "python",
			Category:   "advertising",
			ToolsCount: 22,
		},
		{
			ID:          "google-ads",
			Name:        "Google Ads MCP",
			Description: "Google Ads platform integration with 30+ tools for search advertising, display campaigns, and conversion tracking",
			RepoURL:     "https://github.com/cohnen/mcp-google-ads.git",
			Command:     "python",
			Args:        []string{"-m", "mcp_google_ads"},
			Port:        8002,
			Status:      "not_installed",
			Env: map[string]string{
				"PYTHONPATH": ".",
			},
			ServerType: "python",
			Category:   "advertising",
			ToolsCount: 30,
		},
		// Phase 1 - High Priority Servers
		{
			ID:          "figma",
			Name:        "Figma MCP",
			Description: "Design collaboration platform with 5 tools for accessing Figma files, adding comments, and viewing design nodes",
			RepoURL:     "https://github.com/MatthewDailey/figma-mcp.git",
			Command:     "npx",
			Args:        []string{"figma-mcp"},
			Port:        8003,
			Status:      "not_installed",
			Env: map[string]string{
				"NODE_ENV": "production",
			},
			ServerType: "nodejs",
			Category:   "design",
			ToolsCount: 5,
		},
		{
			ID:          "github",
			Name:        "GitHub MCP",
			Description: "Version control and development collaboration with 12 tools for repository management, issues, and pull requests",
			RepoURL:     "https://github.com/modelcontextprotocol/servers.git",
			Command:     "npx",
			Args:        []string{"-y", "@modelcontextprotocol/server-github"},
			Port:        8004,
			Status:      "not_installed",
			Env: map[string]string{
				"NODE_ENV": "production",
			},
			ServerType: "nodejs",
			Category:   "development",
			ToolsCount: 12,
			SubPath:    "src/github",
		},
		{
			ID:          "slack",
			Name:        "Slack MCP",
			Description: "Team communication and workspace management with 10 tools for messaging, channels, and integrations",
			RepoURL:     "https://github.com/modelcontextprotocol/servers.git",
			Command:     "npx",
			Args:        []string{"-y", "@modelcontextprotocol/server-slack"},
			Port:        8005,
			Status:      "not_installed",
			Env: map[string]string{
				"NODE_ENV": "production",
			},
			ServerType: "nodejs",
			Category:   "communication",
			ToolsCount: 10,
			SubPath:    "src/slack",
		},
		{
			ID:          "notion",
			Name:        "Notion MCP",
			Description: "All-in-one workspace with 7 tools for notes, databases, and collaborative documentation",
			RepoURL:     "https://github.com/modelcontextprotocol/servers.git",
			Command:     "npx",
			Args:        []string{"-y", "@modelcontextprotocol/server-notion"},
			Port:        8006,
			Status:      "not_installed",
			Env: map[string]string{
				"NODE_ENV": "production",
			},
			ServerType: "nodejs",
			Category:   "productivity",
			ToolsCount: 7,
			SubPath:    "src/notion",
		},
		{
			ID:          "stripe",
			Name:        "Stripe MCP",
			Description: "Payment processing and billing with 12 tools for transactions, subscriptions, and customer management",
			RepoURL:     "https://github.com/modelcontextprotocol/servers.git",
			Command:     "npx",
			Args:        []string{"-y", "@modelcontextprotocol/server-stripe"},
			Port:        8007,
			Status:      "not_installed",
			Env: map[string]string{
				"NODE_ENV": "production",
			},
			ServerType: "nodejs",
			Category:   "ecommerce",
			ToolsCount: 12,
			SubPath:    "src/stripe",
		},
		// Phase 2 - Short-term Priority
		{
			ID:          "google-maps",
			Name:        "Google Maps MCP",
			Description: "Location services and mapping with 6 tools for geocoding, directions, and place searches",
			RepoURL:     "https://github.com/modelcontextprotocol/servers.git",
			Command:     "npx",
			Args:        []string{"-y", "@modelcontextprotocol/server-google-maps"},
			Port:        8008,
			Status:      "not_installed",
			Env: map[string]string{
				"NODE_ENV": "production",
			},
			ServerType: "nodejs",
			Category:   "maps",
			ToolsCount: 6,
			SubPath:    "src/google-maps",
		},
		{
			ID:          "brave-search",
			Name:        "Brave Search MCP",
			Description: "Web search and data retrieval with 3 tools for search queries and result processing",
			RepoURL:     "https://github.com/modelcontextprotocol/servers.git",
			Command:     "npx",
			Args:        []string{"-y", "@modelcontextprotocol/server-brave-search"},
			Port:        8009,
			Status:      "not_installed",
			Env: map[string]string{
				"NODE_ENV": "production",
			},
			ServerType: "nodejs",
			Category:   "web_browser",
			ToolsCount: 3,
			SubPath:    "src/brave-search",
		},
		{
			ID:          "gmail",
			Name:        "Gmail MCP",
			Description: "Gmail integration with 9 tools for email management, sending, and organization",
			RepoURL:     "https://github.com/modelcontextprotocol/servers.git",
			Command:     "npx",
			Args:        []string{"-y", "@modelcontextprotocol/server-gmail"},
			Port:        8010,
			Status:      "not_installed",
			Env: map[string]string{
				"NODE_ENV": "production",
			},
			ServerType: "nodejs",
			Category:   "email",
			ToolsCount: 9,
			SubPath:    "src/gmail",
		},
		{
			ID:          "puppeteer",
			Name:        "Puppeteer MCP",
			Description: "Web scraping and automation with 5 tools for browser control and page interaction",
			RepoURL:     "https://github.com/modelcontextprotocol/servers.git",
			Command:     "npx",
			Args:        []string{"-y", "@modelcontextprotocol/server-puppeteer"},
			Port:        8011,
			Status:      "not_installed",
			Env: map[string]string{
				"NODE_ENV": "production",
			},
			ServerType: "nodejs",
			Category:   "web_browser",
			ToolsCount: 5,
			SubPath:    "src/puppeteer",
		},
		{
			ID:          "docker",
			Name:        "Docker MCP",
			Description: "Container management with 8 tools for Docker operations, images, and deployments",
			RepoURL:     "https://github.com/modelcontextprotocol/servers.git",
			Command:     "npx",
			Args:        []string{"-y", "@modelcontextprotocol/server-docker"},
			Port:        8012,
			Status:      "not_installed",
			Env: map[string]string{
				"NODE_ENV": "production",
			},
			ServerType: "nodejs",
			Category:   "cloud",
			ToolsCount: 8,
			SubPath:    "src/docker",
		},
	}
}

// InstallServer installs a new MCP server
func (m *Manager) InstallServer(serverID string, config map[string]string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Get the server template
	var serverTemplate *ServerConfig
	for _, server := range m.GetAvailableServers() {
		if server.ID == serverID {
			serverTemplate = server
			break
		}
	}

	if serverTemplate == nil {
		return fmt.Errorf("server %s not found", serverID)
	}

	// Create a copy of the template
	server := *serverTemplate
	server.InstallPath = filepath.Join(m.basePath, serverID)
	server.Status = "installing"

	// Add to servers map
	m.servers[serverID] = &server

	// Start installation in a goroutine
	go m.performInstallation(&server, config)

	return nil
}

// performInstallation handles the actual installation process
func (m *Manager) performInstallation(server *ServerConfig, config map[string]string) {
	log.Printf("Starting installation of %s", server.Name)

	// Clear previous errors for this server
	m.ClearErrors(server.ID)

	// Create error handler for this installation
	errorHandler := NewErrorHandler(server.ID, fmt.Sprintf("Installing %s", server.Name))

	// Clone the repository
	if err := m.cloneRepo(server.RepoURL, server.InstallPath); err != nil {
		enhancedErr := errorHandler.HandleInstallationError(err, "git_clone")
		m.AddError(server.ID, enhancedErr)
		log.Printf("Failed to clone repo: %v", err)
		server.Status = "failed"
		server.Logs = append(server.Logs, enhancedErr.Message)
		return
	}

	// Install dependencies and build
	if err := m.buildServer(server); err != nil {
		// Determine the stage based on server type
		stage := "npm_build"
		if server.ServerType == "python" {
			stage = "pip_install"
		}
		enhancedErr := errorHandler.HandleInstallationError(err, stage)
		m.AddError(server.ID, enhancedErr)
		log.Printf("Failed to build server: %v", err)
		server.Status = "failed"
		server.Logs = append(server.Logs, enhancedErr.Message)
		return
	}

	// Create environment file
	if err := m.createEnvFile(server.InstallPath, config); err != nil {
		enhancedErr := errorHandler.HandleInstallationError(err, "env_file")
		m.AddError(server.ID, enhancedErr)
		log.Printf("Failed to create env file: %v", err)
		server.Status = "failed"
		server.Logs = append(server.Logs, enhancedErr.Message)
		return
	}

	// Validate installation and attempt auto-fix if needed
	log.Printf("Validating installation of %s", server.Name)
	validationResult := m.validator.ValidateServer(server.ID, server)

	if !validationResult.IsValid {
		log.Printf("Server %s validation failed, attempting auto-fix", server.Name)
		if err := m.validator.AutoFixIssues(validationResult); err != nil {
			enhancedErr := errorHandler.HandleInstallationError(err, "validation")
			m.AddError(server.ID, enhancedErr)
			log.Printf("Auto-fix failed for %s: %v", server.Name, err)
			server.Status = "failed"
			server.Logs = append(server.Logs, enhancedErr.Message)
			return
		}

		// Re-validate after auto-fix
		validationResult = m.validator.ValidateServer(server.ID, server)
		if !validationResult.IsValid {
			validationErr := fmt.Errorf("validation still failed after auto-fix")
			enhancedErr := errorHandler.HandleInstallationError(validationErr, "validation")
			m.AddError(server.ID, enhancedErr)
			log.Printf("Server %s still invalid after auto-fix", server.Name)
			server.Status = "failed"
			server.Logs = append(server.Logs, enhancedErr.Message)
			return
		}
	}

	server.Status = "installed"
	log.Printf("Successfully installed and validated %s", server.Name)

	// Save server state after successful installation
	if err := m.saveServerState(); err != nil {
		log.Printf("Warning: Failed to save server state after installation: %v", err)
	}

	// Configure Claude Desktop after successful installation
	if err := m.configureClaudeDesktop(); err != nil {
		log.Printf("Failed to configure Claude Desktop: %v", err)
		// Don't fail the installation if Claude Desktop configuration fails
	}
}

// cloneRepo clones a Git repository
func (m *Manager) cloneRepo(repoURL, installPath string) error {
	// Remove existing directory if it exists
	if _, err := os.Stat(installPath); err == nil {
		log.Printf("Removing existing directory: %s", installPath)
		if err := os.RemoveAll(installPath); err != nil {
			return fmt.Errorf("failed to remove existing directory: %v", err)
		}
	}

	cmd := exec.Command("git", "clone", repoURL, installPath)
	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("Git clone failed. Command: git clone %s %s", repoURL, installPath)
		log.Printf("Git error output: %s", string(output))
		return fmt.Errorf("git clone failed: %s", string(output))
	}
	return nil
}

// buildServer builds the MCP server based on server type
func (m *Manager) buildServer(server *ServerConfig) error {
	switch server.ServerType {
	case "nodejs":
		return m.buildNodeJSServer(server.InstallPath)
	case "python":
		return m.buildPythonServer(server.InstallPath)
	default:
		// Default to Node.js for backward compatibility
		return m.buildNodeJSServer(server.InstallPath)
	}
}

// buildNodeJSServer builds a Node.js MCP server
func (m *Manager) buildNodeJSServer(installPath string) error {
	// Install dependencies
	cmd := exec.Command("npm", "install")
	cmd.Dir = installPath
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("npm install failed: %v", err)
	}

	// Build the project
	cmd = exec.Command("npm", "run", "build")
	cmd.Dir = installPath
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("npm build failed: %v", err)
	}

	return nil
}

// buildPythonServer builds a Python MCP server
func (m *Manager) buildPythonServer(installPath string) error {
	// Check if uv is available (faster package manager)
	if _, err := exec.LookPath("uv"); err == nil {
		return m.buildPythonWithUV(installPath)
	}

	// Fall back to pip
	return m.buildPythonWithPip(installPath)
}

// buildPythonWithUV builds using uv package manager
func (m *Manager) buildPythonWithUV(installPath string) error {
	// Create virtual environment with uv
	cmd := exec.Command("uv", "venv", "venv")
	cmd.Dir = installPath
	if err := cmd.Run(); err != nil {
		log.Printf("Failed to create uv venv, falling back to pip: %v", err)
		return m.buildPythonWithPip(installPath)
	}

	// Install dependencies with uv
	cmd = exec.Command("uv", "pip", "install", "-e", ".")
	cmd.Dir = installPath
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("uv pip install failed: %v", err)
	}

	return nil
}

// buildPythonWithPip builds using standard pip
func (m *Manager) buildPythonWithPip(installPath string) error {
	// Create virtual environment
	cmd := exec.Command("python3", "-m", "venv", "venv")
	cmd.Dir = installPath
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("python venv creation failed: %v", err)
	}

	// Determine pip path based on OS
	pipPath := filepath.Join(installPath, "venv", "bin", "pip")
	if _, err := os.Stat(pipPath); os.IsNotExist(err) {
		// Windows path
		pipPath = filepath.Join(installPath, "venv", "Scripts", "pip.exe")
	}

	// Upgrade pip
	cmd = exec.Command(pipPath, "install", "--upgrade", "pip")
	cmd.Dir = installPath
	if err := cmd.Run(); err != nil {
		log.Printf("Failed to upgrade pip: %v", err)
		// Continue anyway, not critical
	}

	// Install dependencies
	// Try installing in editable mode first
	cmd = exec.Command(pipPath, "install", "-e", ".")
	cmd.Dir = installPath
	if err := cmd.Run(); err != nil {
		// If editable install fails, try installing from requirements.txt
		if _, statErr := os.Stat(filepath.Join(installPath, "requirements.txt")); statErr == nil {
			cmd = exec.Command(pipPath, "install", "-r", "requirements.txt")
			cmd.Dir = installPath
			if err := cmd.Run(); err != nil {
				return fmt.Errorf("pip install from requirements.txt failed: %v", err)
			}
		} else {
			return fmt.Errorf("pip install failed and no requirements.txt found: %v", err)
		}
	}

	return nil
}

// createEnvFile creates the environment configuration file
func (m *Manager) createEnvFile(installPath string, config map[string]string) error {
	envFile := filepath.Join(installPath, ".env")

	file, err := os.Create(envFile)
	if err != nil {
		return err
	}
	defer file.Close()

	for key, value := range config {
		file.WriteString(fmt.Sprintf("%s=%s\n", key, value))
	}

	return nil
}

// StartServer starts an MCP server
func (m *Manager) StartServer(serverID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	log.Printf("DEBUG: StartServer called for ID: %s", serverID) // DEBUG

	server, exists := m.servers[serverID]
	if !exists {
		log.Printf("DEBUG: Server %s not found in manager's map", serverID) // DEBUG
		return fmt.Errorf("server %s not found", serverID)
	}

	if server.Status == "running" {
		log.Printf("DEBUG: Server %s is already running", serverID) // DEBUG
		return fmt.Errorf("server %s is already running", serverID)
	}

	// Create error handler for startup
	errorHandler := NewErrorHandler(serverID, fmt.Sprintf("Starting %s", server.Name))
	log.Printf("DEBUG: Error handler created for %s", serverID) // DEBUG

	// Validate server configuration before starting
	log.Printf("Validating server %s before start", server.Name)
	validationResult := m.validator.ValidateServer(serverID, server)
	log.Printf("DEBUG: Initial validation complete. IsValid: %t", validationResult.IsValid) // DEBUG

	if !validationResult.IsValid {
		log.Printf("Server %s validation failed, attempting auto-fix before start", server.Name)
		if err := m.validator.AutoFixIssues(validationResult); err != nil {
			log.Printf("DEBUG: Auto-fix failed with error: %v", err) // DEBUG
			enhancedErr := errorHandler.HandleStartupError(fmt.Errorf("server validation failed and auto-fix unsuccessful: %v", err))
			m.AddError(serverID, enhancedErr)
			return fmt.Errorf("server validation failed and auto-fix unsuccessful: %v", err)
		}

		// Re-validate after auto-fix
		log.Printf("DEBUG: Re-validating after auto-fix") // DEBUG
		validationResult = m.validator.ValidateServer(serverID, server)
		if !validationResult.IsValid {
			log.Printf("DEBUG: Validation still failed after auto-fix") // DEBUG
			validationErr := fmt.Errorf("server %s is not valid and cannot be started", serverID)
			enhancedErr := errorHandler.HandleStartupError(validationErr)
			m.AddError(serverID, enhancedErr)
			return validationErr
		}
		log.Printf("Server %s auto-fix successful, proceeding with start", server.Name)
	}

	// Prepare command based on server type
	var cmd *exec.Cmd
	log.Printf("DEBUG: Preparing command for server type: %s", server.ServerType) // DEBUG

	if server.ServerType == "python" {
		// Use virtual environment Python for Python servers
		pythonPath := filepath.Join(server.InstallPath, "venv", "bin", "python")
		if _, err := os.Stat(pythonPath); os.IsNotExist(err) {
			// Windows path
			pythonPath = filepath.Join(server.InstallPath, "venv", "Scripts", "python.exe")
		}

		// Create command with virtual environment python
		args := append([]string{pythonPath}, server.Args...)
		log.Printf("DEBUG: Python command: %s %v", args[0], args[1:]) // DEBUG
		cmd = exec.Command(args[0], args[1:]...)
	} else if server.ServerType == "nodejs" && server.Command == "node" {
		// For Node.js servers started with 'node', use relative path from working directory
		log.Printf("DEBUG: Starting Node.js server with command: %s %v in directory: %s", server.Command, server.Args, server.InstallPath)
		cmd = exec.Command(server.Command, server.Args...)
	} else {
		// Node.js (npx) and other servers
		log.Printf("DEBUG: Generic command: %s %v", server.Command, server.Args) // DEBUG
		cmd = exec.Command(server.Command, server.Args...)
	}

	cmd.Dir = server.InstallPath
	log.Printf("DEBUG: Command directory set to: %s", cmd.Dir) // DEBUG

	// Set environment variables
	env := os.Environ()
	for key, value := range server.Env {
		env = append(env, fmt.Sprintf("%s=%s", key, value))
	}
	cmd.Env = env
	log.Printf("DEBUG: Environment variables prepared for command.") // DEBUG

	if err := cmd.Start(); err != nil {
		log.Printf("DEBUG: cmd.Start() failed with error: %v", err) // DEBUG
		enhancedErr := errorHandler.HandleStartupError(err)
		m.AddError(serverID, enhancedErr)
		server.Logs = append(server.Logs, enhancedErr.Message)
		return fmt.Errorf("failed to start server: %v", err)
	}
	log.Printf("DEBUG: cmd.Start() successful. PID: %d", cmd.Process.Pid) // DEBUG

	server.Process = cmd.Process
	server.Status = "running"
	log.Printf("DEBUG: Server status set to 'running' for %s", serverID) // DEBUG

	// Register with orchestrator
	mcpServer := &mcp.MCPServer{
		ID:     serverID,
		Name:   server.Name,
		Status: "running",
		Port:   server.Port,
	}
	m.orchestrator.RegisterServer(mcpServer)

	log.Printf("Started server %s (PID: %d)", server.Name, cmd.Process.Pid)
	return nil
}

// StopServer stops an MCP server
func (m *Manager) StopServer(serverID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	log.Printf("DEBUG: StopServer called for ID: %s", serverID) // DEBUG

	server, exists := m.servers[serverID]
	if !exists {
		// If server is not in the in-memory map, it might be because the orchestrator restarted.
		// In this case, there is no process to kill, so we can consider it "stopped".
		log.Printf("Server %s not found in active manager, considering it stopped.", serverID)
		return nil
	}

	if server.Process != nil {
		if err := server.Process.Kill(); err != nil {
			log.Printf("Failed to kill process for server %s: %v", server.Name, err)
			// Don't return an error, as the process might already be dead.
		}
		server.Process = nil
	}

	server.Status = "stopped"
	log.Printf("Stopped server %s", server.Name)
	return nil
}

// StopAll stops all running servers
func (m *Manager) StopAll() {
	m.mu.Lock()
	defer m.mu.Unlock()

	for _, server := range m.servers {
		if server.Process != nil {
			server.Process.Kill()
			server.Process = nil
		}
		server.Status = "stopped"
	}
}

// GetServer returns a specific server configuration
func (m *Manager) GetServer(serverID string) (*ServerConfig, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	server, exists := m.servers[serverID]
	if !exists {
		return nil, fmt.Errorf("server %s not found", serverID)
	}

	return server, nil
}

// ListServers returns all available servers with their current status
func (m *Manager) ListServers() []*ServerConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()

	// Start with all available servers
	availableServers := m.GetAvailableServers()
	servers := make([]*ServerConfig, 0, len(availableServers))

	for _, available := range availableServers {
		// Check if this server is installed
		if installed, exists := m.servers[available.ID]; exists {
			// Return the installed server with its current status
			servers = append(servers, installed)
		} else {
			// Return the available server with "not_installed" status
			serverCopy := *available
			serverCopy.Status = "not_installed"
			servers = append(servers, &serverCopy)
		}
	}

	return servers
}

// configureClaudeDesktop automatically configures Claude Desktop to connect to the MCP orchestrator
func (m *Manager) configureClaudeDesktop() error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get user home directory: %v", err)
	}

	claudeConfigDir := filepath.Join(homeDir, "Library", "Application Support", "Claude")
	claudeConfigFile := filepath.Join(claudeConfigDir, "claude_desktop_config.json")

	// Create Claude config directory if it doesn't exist
	if err := os.MkdirAll(claudeConfigDir, 0755); err != nil {
		return fmt.Errorf("failed to create Claude config directory: %v", err)
	}

	// Read existing configuration if it exists
	var config ClaudeDesktopConfig
	if data, err := os.ReadFile(claudeConfigFile); err == nil {
		if err := json.Unmarshal(data, &config); err != nil {
			log.Printf("Failed to parse existing Claude config, creating new: %v", err)
			config = ClaudeDesktopConfig{MCPServers: make(map[string]MCPServerConfig)}
		}
	} else {
		// File doesn't exist, create new config
		config = ClaudeDesktopConfig{MCPServers: make(map[string]MCPServerConfig)}
	}

	// Clean up any invalid entries
	if config.MCPServers == nil {
		config.MCPServers = make(map[string]MCPServerConfig)
	}

	// Remove any invalid entries that might cause validation errors
	validServers := make(map[string]MCPServerConfig)
	for name, server := range config.MCPServers {
		// Only keep servers that have command and args properly configured
		// Claude Desktop requires command/args format for all MCP servers
		if server.Command != "" && len(server.Args) > 0 {
			validServers[name] = server
		} else {
			log.Printf("Removing invalid MCP server config: %s (missing command/args)", name)
		}
	}
	config.MCPServers = validServers

	// Add or update the MCP orchestrator configuration
	// Use our custom stdio proxy instead of mcp-remote
	stdioBinaryPath := filepath.Join(homeDir, "Downloads", "n8", "mcp_orchestrator", "bin", "mcp-orchestrator-stdio")
	config.MCPServers["mcp-orchestrator"] = MCPServerConfig{
		Command: stdioBinaryPath,
		Args:    []string{},
	}

	// Write the updated configuration
	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal Claude config: %v", err)
	}

	if err := os.WriteFile(claudeConfigFile, data, 0644); err != nil {
		return fmt.Errorf("failed to write Claude config file: %v", err)
	}

	log.Printf("Successfully configured Claude Desktop at %s", claudeConfigFile)
	log.Printf("Please restart Claude Desktop to apply the new configuration")
	return nil
}

// AddError adds an enhanced error for a server
func (m *Manager) AddError(serverID string, enhancedError *EnhancedError) {
	m.errorsMu.Lock()
	defer m.errorsMu.Unlock()

	if m.errors[serverID] == nil {
		m.errors[serverID] = []*EnhancedError{}
	}

	m.errors[serverID] = append(m.errors[serverID], enhancedError)

	// Keep only the last 10 errors per server to prevent memory bloat
	if len(m.errors[serverID]) > 10 {
		m.errors[serverID] = m.errors[serverID][len(m.errors[serverID])-10:]
	}
}

// GetErrors returns all errors for a server
func (m *Manager) GetErrors(serverID string) []*EnhancedError {
	m.errorsMu.RLock()
	defer m.errorsMu.RUnlock()

	if errors, exists := m.errors[serverID]; exists {
		// Return a copy to prevent concurrent modification
		result := make([]*EnhancedError, len(errors))
		copy(result, errors)
		return result
	}

	return []*EnhancedError{}
}

// ClearErrors clears all errors for a server
func (m *Manager) ClearErrors(serverID string) {
	m.errorsMu.Lock()
	defer m.errorsMu.Unlock()

	delete(m.errors, serverID)
}

// GetAllErrors returns errors for all servers
func (m *Manager) GetAllErrors() map[string][]*EnhancedError {
	m.errorsMu.RLock()
	defer m.errorsMu.RUnlock()

	result := make(map[string][]*EnhancedError)
	for serverID, errors := range m.errors {
		result[serverID] = make([]*EnhancedError, len(errors))
		copy(result[serverID], errors)
	}

	return result
}

// saveServerState persists server installation state to disk
func (m *Manager) saveServerState() error {
	stateFile := filepath.Join(m.basePath, "server_state.json")

	// Create a serializable version of server configs (excluding Process field)
	serializableServers := make(map[string]*ServerConfig)
	for id, server := range m.servers {
		// Create a copy without the Process field
		serverCopy := *server
		serverCopy.Process = nil // Don't serialize the process
		serializableServers[id] = &serverCopy
	}

	data, err := json.MarshalIndent(serializableServers, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal server state: %v", err)
	}

	if err := os.WriteFile(stateFile, data, 0644); err != nil {
		return fmt.Errorf("failed to write server state file: %v", err)
	}

	log.Printf("Successfully saved server state to %s", stateFile)
	return nil
}

// loadServerState loads server installation state from disk
func (m *Manager) loadServerState() error {
	stateFile := filepath.Join(m.basePath, "server_state.json")

	// If state file doesn't exist, try to detect installations from filesystem
	if _, err := os.Stat(stateFile); os.IsNotExist(err) {
		log.Printf("No server state file found, detecting installations from filesystem...")
		return m.detectExistingInstallations()
	}

	data, err := os.ReadFile(stateFile)
	if err != nil {
		log.Printf("Failed to read server state file, falling back to filesystem detection: %v", err)
		return m.detectExistingInstallations()
	}

	var savedServers map[string]*ServerConfig
	if err := json.Unmarshal(data, &savedServers); err != nil {
		log.Printf("Failed to parse server state file, falling back to filesystem detection: %v", err)
		return m.detectExistingInstallations()
	}

	// Validate that saved servers still exist on disk and update their status
	for id, server := range savedServers {
		if _, err := os.Stat(server.InstallPath); err == nil {
			// Server directory exists, mark as installed but not running
			server.Status = "installed"
			server.Process = nil // Ensure process is nil after restart

			// Load environment variables from .env file
			if envVars, err := m.loadEnvFile(server.InstallPath); err == nil {
				server.Env = envVars
				log.Printf("Loaded %d environment variables for %s", len(envVars), server.Name)
			} else {
				log.Printf("Warning: Failed to load environment variables for %s: %v", server.Name, err)
			}

			m.servers[id] = server
			log.Printf("Loaded existing installation: %s at %s", server.Name, server.InstallPath)
		} else {
			log.Printf("Server %s installation not found at %s, skipping", server.Name, server.InstallPath)
		}
	}

	log.Printf("Successfully loaded %d server installations from state file", len(m.servers))
	return nil
}

// detectExistingInstallations scans the filesystem for existing server installations
func (m *Manager) detectExistingInstallations() error {
	log.Printf("Scanning %s for existing server installations...", m.basePath)

	entries, err := os.ReadDir(m.basePath)
	if err != nil {
		return fmt.Errorf("failed to read base directory: %v", err)
	}

	availableServers := m.GetAvailableServers()
	serverMap := make(map[string]*ServerConfig)
	for _, server := range availableServers {
		serverMap[server.ID] = server
	}

	detectedCount := 0
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		serverID := entry.Name()
		installPath := filepath.Join(m.basePath, serverID)

		// Check if this matches a known server
		if template, exists := serverMap[serverID]; exists {
			// Verify the installation looks valid
			if m.validateInstallationDirectory(installPath, template) {
				// Create server config based on template
				server := *template
				server.InstallPath = installPath
				server.Status = "installed"
				server.Process = nil

				// Load environment variables from .env file
				if envVars, err := m.loadEnvFile(installPath); err == nil {
					server.Env = envVars
					log.Printf("Loaded %d environment variables for detected server %s", len(envVars), server.Name)
				} else {
					log.Printf("Warning: Failed to load environment variables for %s: %v", server.Name, err)
					// Keep the default environment variables from template
				}

				m.servers[serverID] = &server
				detectedCount++
				log.Printf("Detected existing installation: %s at %s", server.Name, installPath)
			}
		}
	}

	if detectedCount > 0 {
		// Save the detected state for future loads
		if err := m.saveServerState(); err != nil {
			log.Printf("Warning: Failed to save detected server state: %v", err)
		}
	}

	log.Printf("Detected %d existing server installations", detectedCount)
	return nil
}

// validateInstallationDirectory checks if a directory contains a valid server installation
func (m *Manager) validateInstallationDirectory(installPath string, template *ServerConfig) bool {
	switch template.ServerType {
	case "nodejs":
		// Check for package.json and node_modules
		packageJson := filepath.Join(installPath, "package.json")
		nodeModules := filepath.Join(installPath, "node_modules")
		if _, err := os.Stat(packageJson); err == nil {
			if _, err := os.Stat(nodeModules); err == nil {
				return true
			}
		}
	case "python":
		// Check for venv directory
		venvPath := filepath.Join(installPath, "venv")
		if _, err := os.Stat(venvPath); err == nil {
			return true
		}
	}
	return false
}

// loadEnvFile loads environment variables from a .env file
func (m *Manager) loadEnvFile(installPath string) (map[string]string, error) {
	envFile := filepath.Join(installPath, ".env")

	// Check if .env file exists
	if _, err := os.Stat(envFile); os.IsNotExist(err) {
		return make(map[string]string), nil // Return empty map if no .env file
	}

	data, err := os.ReadFile(envFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read .env file: %v", err)
	}

	envVars := make(map[string]string)
	lines := strings.Split(string(data), "\n")

	for _, line := range lines {
		line = strings.TrimSpace(line)

		// Skip empty lines and comments
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		// Parse KEY=VALUE format
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			key := strings.TrimSpace(parts[0])
			value := strings.TrimSpace(parts[1])
			envVars[key] = value
		}
	}

	return envVars, nil
}
