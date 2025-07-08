package servers

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// ConfigValidator validates and fixes MCP server configurations
type ConfigValidator struct {
	basePath string
}

// ValidationResult contains validation findings
type ValidationResult struct {
	ServerID    string                 `json:"server_id"`
	IsValid     bool                   `json:"is_valid"`
	Issues      []ValidationIssue      `json:"issues"`
	Suggestions []ValidationSuggestion `json:"suggestions"`
}

// ValidationIssue represents a configuration problem
type ValidationIssue struct {
	Type        string `json:"type"`
	Severity    string `json:"severity"`
	Description string `json:"description"`
	Field       string `json:"field,omitempty"`
}

// ValidationSuggestion provides actionable fixes
type ValidationSuggestion struct {
	Action      string `json:"action"`
	Description string `json:"description"`
	Command     string `json:"command,omitempty"`
	AutoFix     bool   `json:"auto_fix"`
}

// NewConfigValidator creates a new validator
func NewConfigValidator(basePath string) *ConfigValidator {
	return &ConfigValidator{
		basePath: basePath,
	}
}

// ValidateAllServers validates all installed servers
func (cv *ConfigValidator) ValidateAllServers(servers map[string]*ServerConfig) []ValidationResult {
	var results []ValidationResult

	for serverID, server := range servers {
		result := cv.ValidateServer(serverID, server)
		results = append(results, result)
	}

	return results
}

// ValidateServer validates a specific server configuration
func (cv *ConfigValidator) ValidateServer(serverID string, server *ServerConfig) ValidationResult {
	result := ValidationResult{
		ServerID:    serverID,
		IsValid:     true,
		Issues:      []ValidationIssue{},
		Suggestions: []ValidationSuggestion{},
	}

	// Check installation path
	if !cv.validateInstallPath(server.InstallPath, &result) {
		result.IsValid = false
	}

	// Check server-specific requirements
	switch serverID {
	case "gohighlevel":
		cv.validateGoHighLevelServer(server, &result)
	case "meta-ads", "google-ads":
		cv.validatePythonServer(server, &result)
	case "github":
		cv.validateNodeJSServerWithCredentials(server, &result, []string{"GITHUB_PERSONAL_ACCESS_TOKEN"})
	case "slack":
		cv.validateNodeJSServerWithCredentials(server, &result, []string{"SLACK_BOT_TOKEN"})
	case "notion":
		cv.validateNodeJSServerWithCredentials(server, &result, []string{"NOTION_API_KEY"})
	case "stripe":
		cv.validateNodeJSServerWithCredentials(server, &result, []string{"STRIPE_SECRET_KEY"})
	case "google-maps":
		cv.validateNodeJSServerWithCredentials(server, &result, []string{"GOOGLE_MAPS_API_KEY"})
	case "gmail":
		cv.validateNodeJSServerWithCredentials(server, &result, []string{"GMAIL_CREDENTIALS"})
	case "figma":
		cv.validateNodeJSServerWithCredentials(server, &result, []string{"FIGMA_ACCESS_TOKEN"})
	case "brave-search":
		cv.validateNodeJSServerWithCredentials(server, &result, []string{"BRAVE_SEARCH_API_KEY"})
	case "puppeteer", "docker":
		// These servers don't require API keys, just basic Node.js validation
		cv.validateNodeJSServer(server, &result)
	default:
		cv.validateNodeJSServer(server, &result)
	}

	// Check Claude Desktop configuration
	cv.validateClaudeDesktopConfig(&result)

	return result
}

// validateInstallPath checks if server is properly installed
func (cv *ConfigValidator) validateInstallPath(installPath string, result *ValidationResult) bool {
	if installPath == "" {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "missing_install_path",
			Severity:    "error",
			Description: "Server install path is not set",
		})
		return false
	}

	if _, err := os.Stat(installPath); os.IsNotExist(err) {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "missing_directory",
			Severity:    "error",
			Description: fmt.Sprintf("Server directory does not exist: %s", installPath),
		})

		result.Suggestions = append(result.Suggestions, ValidationSuggestion{
			Action:      "reinstall_server",
			Description: "Reinstall the server through the MCP Orchestrator UI",
			AutoFix:     false,
		})
		return false
	}

	return true
}

// validateGoHighLevelServer validates GoHighLevel specific requirements
func (cv *ConfigValidator) validateGoHighLevelServer(server *ServerConfig, result *ValidationResult) {
	installPath := server.InstallPath

	// Check for package.json
	packageJsonPath := filepath.Join(installPath, "package.json")
	if _, err := os.Stat(packageJsonPath); os.IsNotExist(err) {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "missing_package_json",
			Severity:    "error",
			Description: "package.json not found - server may not be properly cloned",
		})
		result.IsValid = false
	}

	// Check for node_modules
	nodeModulesPath := filepath.Join(installPath, "node_modules")
	if _, err := os.Stat(nodeModulesPath); os.IsNotExist(err) {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "missing_dependencies",
			Severity:    "error",
			Description: "node_modules directory not found - dependencies not installed",
		})

		result.Suggestions = append(result.Suggestions, ValidationSuggestion{
			Action:      "install_dependencies",
			Description: "Install Node.js dependencies",
			Command:     "cd " + installPath + " && npm install",
			AutoFix:     true,
		})
		result.IsValid = false
	}

	// Check for built distribution
	distPath := filepath.Join(installPath, "dist", "server.js")
	if _, err := os.Stat(distPath); os.IsNotExist(err) {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "not_built",
			Severity:    "error",
			Description: "Built distribution not found - server needs to be compiled",
		})

		result.Suggestions = append(result.Suggestions, ValidationSuggestion{
			Action:      "build_server",
			Description: "Build the server from source",
			Command:     "cd " + installPath + " && npm run build",
			AutoFix:     true,
		})
		result.IsValid = false
	}

	// Check for required environment variables
	requiredEnvVars := []string{"GHL_API_KEY", "GHL_LOCATION_ID"}
	cv.checkRequiredEnvVars(installPath, requiredEnvVars, result)
}

// validatePythonServer validates Python MCP servers
func (cv *ConfigValidator) validatePythonServer(server *ServerConfig, result *ValidationResult) {
	installPath := server.InstallPath

	// Check for virtual environment
	venvPath := filepath.Join(installPath, "venv")
	if _, err := os.Stat(venvPath); os.IsNotExist(err) {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "missing_venv",
			Severity:    "error",
			Description: "Python virtual environment not found",
		})

		result.Suggestions = append(result.Suggestions, ValidationSuggestion{
			Action:      "create_venv",
			Description: "Create Python virtual environment",
			Command:     "cd " + installPath + " && python3 -m venv venv",
			AutoFix:     true,
		})
		result.IsValid = false
		return
	}

	// Check for Python executable in venv
	pythonPaths := []string{
		filepath.Join(venvPath, "bin", "python"),
		filepath.Join(venvPath, "Scripts", "python.exe"),
	}

	pythonFound := false
	for _, pythonPath := range pythonPaths {
		if _, err := os.Stat(pythonPath); err == nil {
			pythonFound = true
			break
		}
	}

	if !pythonFound {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "invalid_venv",
			Severity:    "error",
			Description: "Python executable not found in virtual environment",
		})
		result.IsValid = false
	}

	// Check for requirements.txt or setup.py
	reqFiles := []string{"requirements.txt", "setup.py", "pyproject.toml"}
	reqFileFound := false
	for _, reqFile := range reqFiles {
		reqPath := filepath.Join(installPath, reqFile)
		if _, err := os.Stat(reqPath); err == nil {
			reqFileFound = true
			break
		}
	}

	if !reqFileFound {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "missing_requirements",
			Severity:    "warning",
			Description: "No requirements file found - dependencies may not be properly defined",
		})
	}

	// Check server-specific environment variables
	serverID := server.ID
	var requiredEnvVars []string

	switch serverID {
	case "meta-ads":
		requiredEnvVars = []string{"META_ACCESS_TOKEN", "META_APP_ID", "META_APP_SECRET"}
	case "google-ads":
		requiredEnvVars = []string{"GOOGLE_ADS_CUSTOMER_ID", "GOOGLE_ADS_DEVELOPER_TOKEN"}
	}

	cv.checkRequiredEnvVars(installPath, requiredEnvVars, result)
}

// validateNodeJSServer validates generic Node.js servers
func (cv *ConfigValidator) validateNodeJSServer(server *ServerConfig, result *ValidationResult) {
	// Check if npm/npx is available globally
	if _, err := exec.LookPath("npm"); err != nil {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "missing_npm",
			Severity:    "error",
			Description: "npm not found in PATH - Node.js may not be properly installed",
		})

		result.Suggestions = append(result.Suggestions, ValidationSuggestion{
			Action:      "install_nodejs",
			Description: "Install Node.js from https://nodejs.org/",
			AutoFix:     false,
		})
		result.IsValid = false
	}

	if _, err := exec.LookPath("npx"); err != nil {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "missing_npx",
			Severity:    "error",
			Description: "npx not found in PATH - Node.js installation may be incomplete",
		})
		result.IsValid = false
	}

	// For npm-based servers, check if the package exists
	serverID := server.ID
	packageName := "@modelcontextprotocol/server-" + serverID

	// Try to check if package exists (this is optional)
	result.Suggestions = append(result.Suggestions, ValidationSuggestion{
		Action:      "test_package",
		Description: fmt.Sprintf("Test if package %s can be installed", packageName),
		Command:     fmt.Sprintf("npx -y %s --help", packageName),
		AutoFix:     false,
	})
}

// validateNodeJSServerWithCredentials validates Node.js servers that require specific credentials
func (cv *ConfigValidator) validateNodeJSServerWithCredentials(server *ServerConfig, result *ValidationResult, requiredEnvVars []string) {
	// First do basic Node.js validation
	cv.validateNodeJSServer(server, result)

	// Check for required environment variables
	cv.checkRequiredEnvVars(server.InstallPath, requiredEnvVars, result)
}

// checkRequiredEnvVars validates required environment variables
func (cv *ConfigValidator) checkRequiredEnvVars(installPath string, requiredVars []string, result *ValidationResult) {
	envFile := filepath.Join(installPath, ".env")
	envVars := make(map[string]string)

	// Load .env file if it exists
	if data, err := os.ReadFile(envFile); err == nil {
		lines := strings.Split(string(data), "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}

			parts := strings.SplitN(line, "=", 2)
			if len(parts) == 2 {
				envVars[parts[0]] = parts[1]
			}
		}
	} else {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "missing_env_file",
			Severity:    "warning",
			Description: "No .env file found - environment variables may not be configured",
		})
	}

	// Check required variables
	for _, varName := range requiredVars {
		if envVars[varName] == "" && os.Getenv(varName) == "" {
			result.Issues = append(result.Issues, ValidationIssue{
				Type:        "missing_env_var",
				Severity:    "error",
				Description: fmt.Sprintf("Required environment variable %s is not set", varName),
				Field:       varName,
			})

			result.Suggestions = append(result.Suggestions, ValidationSuggestion{
				Action:      "configure_env_var",
				Description: fmt.Sprintf("Set %s in the server configuration", varName),
				AutoFix:     false,
			})
			result.IsValid = false
		}
	}
}

// validateClaudeDesktopConfig checks Claude Desktop configuration
func (cv *ConfigValidator) validateClaudeDesktopConfig(result *ValidationResult) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "env_error",
			Severity:    "error",
			Description: "Could not determine user home directory",
		})
		return
	}

	claudeConfigFile := filepath.Join(homeDir, "Library", "Application Support", "Claude", "claude_desktop_config.json")

	if _, err := os.Stat(claudeConfigFile); os.IsNotExist(err) {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "missing_claude_config",
			Severity:    "error",
			Description: "Claude Desktop configuration file not found",
		})

		result.Suggestions = append(result.Suggestions, ValidationSuggestion{
			Action:      "create_claude_config",
			Description: "Create Claude Desktop configuration file",
			AutoFix:     true,
		})
		result.IsValid = false
		return
	}

	// Read and validate Claude config
	data, err := os.ReadFile(claudeConfigFile)
	if err != nil {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "claude_config_read_error",
			Severity:    "error",
			Description: fmt.Sprintf("Could not read Claude Desktop config: %v", err),
		})
		return
	}

	var config ClaudeDesktopConfig
	if err := json.Unmarshal(data, &config); err != nil {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "claude_config_invalid_json",
			Severity:    "error",
			Description: "Claude Desktop config contains invalid JSON",
		})
		result.IsValid = false
		return
	}

	// Check if MCP orchestrator is configured
	if config.MCPServers == nil {
		config.MCPServers = make(map[string]MCPServerConfig)
	}

	orchestratorConfig, exists := config.MCPServers["mcp-orchestrator"]
	if !exists {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "missing_orchestrator_config",
			Severity:    "error",
			Description: "MCP Orchestrator not configured in Claude Desktop",
		})

		result.Suggestions = append(result.Suggestions, ValidationSuggestion{
			Action:      "add_orchestrator_config",
			Description: "Add MCP Orchestrator to Claude Desktop configuration",
			AutoFix:     true,
		})
		result.IsValid = false
		return
	}

	// Validate orchestrator configuration
	if orchestratorConfig.Command == "" {
		result.Issues = append(result.Issues, ValidationIssue{
			Type:        "invalid_orchestrator_config",
			Severity:    "error",
			Description: "MCP Orchestrator command not specified in Claude Desktop config",
		})
		result.IsValid = false
	}

	// Check if the command path exists
	if orchestratorConfig.Command != "" {
		if _, err := os.Stat(orchestratorConfig.Command); os.IsNotExist(err) {
			result.Issues = append(result.Issues, ValidationIssue{
				Type:        "orchestrator_binary_missing",
				Severity:    "error",
				Description: fmt.Sprintf("MCP Orchestrator binary not found at: %s", orchestratorConfig.Command),
			})

			result.Suggestions = append(result.Suggestions, ValidationSuggestion{
				Action:      "fix_orchestrator_path",
				Description: "Update the path to the MCP Orchestrator binary",
				AutoFix:     true,
			})
			result.IsValid = false
		}
	}
}

// AutoFixIssues attempts to automatically fix validation issues
func (cv *ConfigValidator) AutoFixIssues(result ValidationResult) error {
	for _, suggestion := range result.Suggestions {
		if !suggestion.AutoFix {
			continue
		}

		switch suggestion.Action {
		case "install_dependencies":
			return cv.runCommand(suggestion.Command)
		case "build_server":
			return cv.runCommand(suggestion.Command)
		case "create_venv":
			return cv.runCommand(suggestion.Command)
		case "create_claude_config":
			return cv.createClaudeConfig()
		case "add_orchestrator_config":
			return cv.addOrchestratorConfig()
		case "fix_orchestrator_path":
			return cv.fixOrchestratorPath()
		}
	}

	return nil
}

// runCommand executes a shell command
func (cv *ConfigValidator) runCommand(command string) error {
	parts := strings.Fields(command)
	if len(parts) == 0 {
		return fmt.Errorf("empty command")
	}

	var cmd *exec.Cmd
	if len(parts) == 1 {
		cmd = exec.Command(parts[0])
	} else {
		cmd = exec.Command(parts[0], parts[1:]...)
	}

	// Extract directory from command if it starts with "cd"
	if strings.HasPrefix(command, "cd ") {
		cmdParts := strings.Split(command, " && ")
		if len(cmdParts) >= 2 {
			dirPart := strings.TrimPrefix(cmdParts[0], "cd ")
			actualCmd := strings.Join(cmdParts[1:], " && ")
			actualParts := strings.Fields(actualCmd)

			if len(actualParts) > 0 {
				cmd = exec.Command(actualParts[0], actualParts[1:]...)
				cmd.Dir = dirPart
			}
		}
	}

	return cmd.Run()
}

// createClaudeConfig creates a basic Claude Desktop configuration
func (cv *ConfigValidator) createClaudeConfig() error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	claudeConfigDir := filepath.Join(homeDir, "Library", "Application Support", "Claude")
	claudeConfigFile := filepath.Join(claudeConfigDir, "claude_desktop_config.json")

	// Create directory if it doesn't exist
	if err := os.MkdirAll(claudeConfigDir, 0755); err != nil {
		return err
	}

	config := ClaudeDesktopConfig{
		MCPServers: make(map[string]MCPServerConfig),
	}

	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(claudeConfigFile, data, 0644)
}

// addOrchestratorConfig adds MCP Orchestrator to Claude Desktop config
func (cv *ConfigValidator) addOrchestratorConfig() error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	claudeConfigFile := filepath.Join(homeDir, "Library", "Application Support", "Claude", "claude_desktop_config.json")

	// Read existing config
	data, err := os.ReadFile(claudeConfigFile)
	if err != nil {
		return err
	}

	var config ClaudeDesktopConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return err
	}

	if config.MCPServers == nil {
		config.MCPServers = make(map[string]MCPServerConfig)
	}

	// Add orchestrator configuration
	stdioBinaryPath := "/usr/local/bin/mcp-orchestrator-stdio"
	config.MCPServers["mcp-orchestrator"] = MCPServerConfig{
		Command: stdioBinaryPath,
		Args:    []string{},
	}

	// Write updated config
	data, err = json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(claudeConfigFile, data, 0644)
}

// fixOrchestratorPath updates the orchestrator binary path
func (cv *ConfigValidator) fixOrchestratorPath() error {
	// Try common paths
	possiblePaths := []string{
		"/usr/local/bin/mcp-orchestrator-stdio",
		"/opt/homebrew/bin/mcp-orchestrator-stdio",
		filepath.Join(os.Getenv("HOME"), "Downloads", "n8", "mcp_orchestrator", "bin", "mcp-orchestrator-stdio"),
	}

	var validPath string
	for _, path := range possiblePaths {
		if _, err := os.Stat(path); err == nil {
			validPath = path
			break
		}
	}

	if validPath == "" {
		return fmt.Errorf("could not find mcp-orchestrator-stdio binary in common locations")
	}

	homeDir, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	claudeConfigFile := filepath.Join(homeDir, "Library", "Application Support", "Claude", "claude_desktop_config.json")

	// Read and update config
	data, err := os.ReadFile(claudeConfigFile)
	if err != nil {
		return err
	}

	var config ClaudeDesktopConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return err
	}

	if config.MCPServers == nil {
		config.MCPServers = make(map[string]MCPServerConfig)
	}

	// Update orchestrator path
	orchestratorConfig := config.MCPServers["mcp-orchestrator"]
	orchestratorConfig.Command = validPath
	config.MCPServers["mcp-orchestrator"] = orchestratorConfig

	// Write updated config
	data, err = json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(claudeConfigFile, data, 0644)
}
