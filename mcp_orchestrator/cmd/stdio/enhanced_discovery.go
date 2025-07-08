package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// EnhancedDiscovery provides robust tool discovery with diagnostics
type EnhancedDiscovery struct {
	orchestratorURL string
	cache           map[string]CachedToolData
	cacheMutex      sync.RWMutex
	diagnostics     *DiagnosticsCollector
}

// CachedToolData stores tools with metadata
type CachedToolData struct {
	Tools     []interface{} `json:"tools"`
	Timestamp time.Time     `json:"timestamp"`
	ServerID  string        `json:"server_id"`
	Status    string        `json:"status"`
	Error     string        `json:"error,omitempty"`
}

// DiagnosticsCollector tracks discovery issues
type DiagnosticsCollector struct {
	Issues []DiagnosticIssue `json:"issues"`
	mutex  sync.RWMutex
}

// DiagnosticIssue represents a specific problem
type DiagnosticIssue struct {
	ServerID    string    `json:"server_id"`
	Type        string    `json:"type"`
	Description string    `json:"description"`
	Timestamp   time.Time `json:"timestamp"`
	Severity    string    `json:"severity"`
	Resolution  string    `json:"resolution,omitempty"`
}

// NewEnhancedDiscovery creates an enhanced discovery system
func NewEnhancedDiscovery(orchestratorURL string) *EnhancedDiscovery {
	return &EnhancedDiscovery{
		orchestratorURL: orchestratorURL,
		cache:           make(map[string]CachedToolData),
		diagnostics:     &DiagnosticsCollector{},
	}
}

// DiscoverToolsWithDiagnostics performs robust tool discovery
func (ed *EnhancedDiscovery) DiscoverToolsWithDiagnostics() ([]interface{}, []DiagnosticIssue) {
	servers := ed.getRunningServers()
	var allTools []interface{}
	var wg sync.WaitGroup
	toolsChan := make(chan CachedToolData, len(servers))

	for _, server := range servers {
		wg.Add(1)
		go func(serverData map[string]interface{}) {
			defer wg.Done()

			serverID, _ := serverData["id"].(string)
			status, _ := serverData["status"].(string)

			if status != "running" {
				ed.addDiagnostic(serverID, "server_not_running",
					fmt.Sprintf("Server %s has status: %s", serverID, status), "warning",
					"Start the server using the MCP Orchestrator UI")
				return
			}

			// Check cache first
			if cached := ed.getCachedTools(serverID); cached != nil {
				toolsChan <- *cached
				return
			}

			// Perform discovery with diagnostics
			tools, err := ed.discoverServerToolsWithRetry(serverID, 3)
			if err != nil {
				ed.addDiagnostic(serverID, "tool_discovery_failed",
					fmt.Sprintf("Failed to discover tools: %v", err), "error",
					"Check server logs, verify credentials, and ensure dependencies are installed")

				toolsChan <- CachedToolData{
					ServerID:  serverID,
					Status:    "error",
					Error:     err.Error(),
					Timestamp: time.Now(),
				}
				return
			}

			cached := CachedToolData{
				Tools:     tools,
				ServerID:  serverID,
				Status:    "success",
				Timestamp: time.Now(),
			}

			ed.setCachedTools(serverID, cached)
			toolsChan <- cached
		}(server)
	}

	wg.Wait()
	close(toolsChan)

	// Collect results
	for cached := range toolsChan {
		if cached.Status == "success" {
			// Add server metadata to each tool
			for _, toolData := range cached.Tools {
				if tool, ok := toolData.(map[string]interface{}); ok {
					tool["_server_id"] = cached.ServerID
					tool["_discovered_at"] = cached.Timestamp.Unix()

					// Set category if not already set
					if tool["category"] == nil || tool["category"] == "" {
						switch cached.ServerID {
						case "gohighlevel":
							tool["category"] = "gohighlevel"
						case "meta-ads":
							tool["category"] = "meta-ads"
						case "google-ads":
							tool["category"] = "google-ads"
						case "github":
							tool["category"] = "development"
						case "puppeteer":
							tool["category"] = "web_browser"
						case "slack":
							tool["category"] = "communication"
						case "gmail":
							tool["category"] = "email"
						case "brave-search":
							tool["category"] = "search"
						case "notion":
							tool["category"] = "productivity"
						case "figma":
							tool["category"] = "design"
						case "google-maps":
							tool["category"] = "maps"
						case "stripe":
							tool["category"] = "payments"
						case "docker":
							tool["category"] = "development"
						default:
							tool["category"] = cached.ServerID
						}
					}

					allTools = append(allTools, tool)
				}
			}
		}
	}

	return allTools, ed.getDiagnostics()
}

// discoverServerToolsWithRetry performs tool discovery with retry logic
func (ed *EnhancedDiscovery) discoverServerToolsWithRetry(serverID string, maxRetries int) ([]interface{}, error) {
	var lastErr error

	for attempt := 1; attempt <= maxRetries; attempt++ {
		tools, err := ed.discoverServerTools(serverID)
		if err == nil {
			if attempt > 1 {
				ed.addDiagnostic(serverID, "retry_success",
					fmt.Sprintf("Tool discovery succeeded on attempt %d", attempt), "info", "")
			}
			return tools, nil
		}

		lastErr = err
		if attempt < maxRetries {
			backoffDelay := time.Duration(attempt) * 2 * time.Second
			ed.addDiagnostic(serverID, "retry_attempt",
				fmt.Sprintf("Retry %d/%d after %v: %v", attempt, maxRetries, backoffDelay, err),
				"warning", "")
			time.Sleep(backoffDelay)
		}
	}

	return nil, fmt.Errorf("failed after %d attempts: %v", maxRetries, lastErr)
}

// discoverServerTools discovers tools for a specific server
func (ed *EnhancedDiscovery) discoverServerTools(serverID string) ([]interface{}, error) {
	serverPath := "/Users/user/.mcp_orchestrator/" + serverID

	// Pre-flight checks
	if err := ed.performPreflightChecks(serverID, serverPath); err != nil {
		return nil, fmt.Errorf("preflight check failed: %v", err)
	}

	// Create MCP messages
	messages := ed.createMCPMessages()
	input := strings.Join(messages, "\n") + "\n"

	// Determine execution strategy based on server type
	cmd, err := ed.createServerCommand(serverID, serverPath)
	if err != nil {
		return nil, fmt.Errorf("failed to create command: %v", err)
	}

	// Execute with extended timeout and monitoring
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	cmd.Stdin = strings.NewReader(input)

	// Use CommandContext for proper timeout handling
	cmdCtx := exec.CommandContext(ctx, cmd.Args[0], cmd.Args[1:]...)
	cmdCtx.Dir = cmd.Dir
	cmdCtx.Env = cmd.Env
	cmdCtx.Stdin = strings.NewReader(input)

	// Capture both stdout and stderr
	output, err := cmdCtx.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("execution failed: %v, output: %s", err, string(output))
	}

	// Parse tools from output
	tools, err := ed.parseToolsFromOutput(string(output))
	if err != nil {
		return nil, fmt.Errorf("failed to parse tools: %v", err)
	}

	if len(tools) == 0 {
		return nil, fmt.Errorf("no tools discovered (output: %s)", string(output))
	}

	return tools, nil
}

// performPreflightChecks validates server environment
func (ed *EnhancedDiscovery) performPreflightChecks(serverID, serverPath string) error {
	// Check if server directory exists
	if _, err := os.Stat(serverPath); os.IsNotExist(err) {
		return fmt.Errorf("server directory does not exist: %s", serverPath)
	}

	// Check for environment file
	envFile := filepath.Join(serverPath, ".env")
	if _, err := os.Stat(envFile); os.IsNotExist(err) {
		ed.addDiagnostic(serverID, "missing_env_file",
			"No .env file found - server may be missing configuration", "warning",
			"Configure the server through the MCP Orchestrator UI")
	}

	// Server-specific checks
	switch serverID {
	case "gohighlevel":
		return ed.checkGoHighLevelRequirements(serverPath)
	case "meta-ads", "google-ads":
		return ed.checkPythonServerRequirements(serverPath)
	default:
		return ed.checkNodeJSServerRequirements(serverPath)
	}
}

// checkGoHighLevelRequirements validates GoHighLevel setup
func (ed *EnhancedDiscovery) checkGoHighLevelRequirements(serverPath string) error {
	// Check for built distribution
	distPath := filepath.Join(serverPath, "dist", "server.js")
	if _, err := os.Stat(distPath); os.IsNotExist(err) {
		return fmt.Errorf("GoHighLevel server not built - missing dist/server.js")
	}

	// Check for node_modules
	nodeModulesPath := filepath.Join(serverPath, "node_modules")
	if _, err := os.Stat(nodeModulesPath); os.IsNotExist(err) {
		return fmt.Errorf("dependencies not installed - missing node_modules")
	}

	return nil
}

// checkPythonServerRequirements validates Python server setup
func (ed *EnhancedDiscovery) checkPythonServerRequirements(serverPath string) error {
	// Check for virtual environment
	venvPath := filepath.Join(serverPath, "venv")
	if _, err := os.Stat(venvPath); os.IsNotExist(err) {
		return fmt.Errorf("virtual environment not found - missing venv directory")
	}

	// Check for Python executable
	pythonPath := filepath.Join(venvPath, "bin", "python")
	if _, err := os.Stat(pythonPath); os.IsNotExist(err) {
		// Try Windows path
		pythonPath = filepath.Join(venvPath, "Scripts", "python.exe")
		if _, err := os.Stat(pythonPath); os.IsNotExist(err) {
			return fmt.Errorf("Python executable not found in virtual environment")
		}
	}

	return nil
}

// checkNodeJSServerRequirements validates Node.js server setup
func (ed *EnhancedDiscovery) checkNodeJSServerRequirements(serverPath string) error {
	// For global npm packages, just check if npm is available
	if _, err := exec.LookPath("npm"); err != nil {
		return fmt.Errorf("npm not found in PATH")
	}

	if _, err := exec.LookPath("npx"); err != nil {
		return fmt.Errorf("npx not found in PATH")
	}

	return nil
}

// createServerCommand creates the appropriate command for server execution
func (ed *EnhancedDiscovery) createServerCommand(serverID, serverPath string) (*exec.Cmd, error) {
	var cmd *exec.Cmd

	switch serverID {
	case "gohighlevel":
		cmd = exec.Command("node", "dist/server.js")
		cmd.Dir = serverPath

	case "meta-ads":
		pythonPath := filepath.Join(serverPath, "venv", "bin", "python")
		if _, err := os.Stat(pythonPath); os.IsNotExist(err) {
			pythonPath = filepath.Join(serverPath, "venv", "Scripts", "python.exe")
		}
		cmd = exec.Command(pythonPath, "-m", "meta_ads_mcp")
		cmd.Dir = serverPath

	case "google-ads":
		pythonPath := filepath.Join(serverPath, "venv", "bin", "python")
		if _, err := os.Stat(pythonPath); os.IsNotExist(err) {
			pythonPath = filepath.Join(serverPath, "venv", "Scripts", "python.exe")
		}
		cmd = exec.Command(pythonPath, "-m", "mcp_google_ads")
		cmd.Dir = serverPath

	default:
		// Generic npm-based servers
		cmd = exec.Command("npx", "-y", "@modelcontextprotocol/server-"+serverID)
		cmd.Dir = serverPath
	}

	// Set environment variables
	env := os.Environ()

	// Load .env file if it exists
	envFile := filepath.Join(serverPath, ".env")
	if envVars, err := ed.loadEnvFile(envFile); err == nil {
		for key, value := range envVars {
			env = append(env, fmt.Sprintf("%s=%s", key, value))
		}
	}

	// Add server-specific environment variables
	env = ed.addServerSpecificEnv(env, serverID)

	cmd.Env = env
	return cmd, nil
}

// loadEnvFile loads environment variables from .env file
func (ed *EnhancedDiscovery) loadEnvFile(filename string) (map[string]string, error) {
	envVars := make(map[string]string)

	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

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

	return envVars, nil
}

// addServerSpecificEnv adds server-specific environment variables
func (ed *EnhancedDiscovery) addServerSpecificEnv(env []string, serverID string) []string {
	switch serverID {
	case "github":
		env = append(env, "GITHUB_PERSONAL_ACCESS_TOKEN="+os.Getenv("GITHUB_PERSONAL_ACCESS_TOKEN"))
	case "slack":
		env = append(env, "SLACK_BOT_TOKEN="+os.Getenv("SLACK_BOT_TOKEN"))
	case "gmail":
		env = append(env, "GMAIL_CLIENT_ID="+os.Getenv("GMAIL_CLIENT_ID"))
		env = append(env, "GMAIL_CLIENT_SECRET="+os.Getenv("GMAIL_CLIENT_SECRET"))
		env = append(env, "GMAIL_REFRESH_TOKEN="+os.Getenv("GMAIL_REFRESH_TOKEN"))
	case "brave-search":
		env = append(env, "BRAVE_SEARCH_API_KEY="+os.Getenv("BRAVE_SEARCH_API_KEY"))
	}

	return env
}

// createMCPMessages creates the standard MCP message sequence
func (ed *EnhancedDiscovery) createMCPMessages() []string {
	initMsg := map[string]interface{}{
		"id":      1,
		"method":  "initialize",
		"jsonrpc": "2.0",
		"params": map[string]interface{}{
			"protocolVersion": "2024-11-05",
			"capabilities":    map[string]interface{}{},
			"clientInfo": map[string]interface{}{
				"name":    "mcp-orchestrator",
				"version": "1.0.0",
			},
		},
	}

	notifyMsg := map[string]interface{}{
		"method":  "notifications/initialized",
		"jsonrpc": "2.0",
	}

	toolsMsg := map[string]interface{}{
		"id":      2,
		"method":  "tools/list",
		"jsonrpc": "2.0",
		"params":  map[string]interface{}{},
	}

	messages := make([]string, 3)

	if data, err := json.Marshal(initMsg); err == nil {
		messages[0] = string(data)
	}

	if data, err := json.Marshal(notifyMsg); err == nil {
		messages[1] = string(data)
	}

	if data, err := json.Marshal(toolsMsg); err == nil {
		messages[2] = string(data)
	}

	return messages
}

// parseToolsFromOutput extracts tools from server output
func (ed *EnhancedDiscovery) parseToolsFromOutput(output string) ([]interface{}, error) {
	lines := strings.Split(output, "\n")

	// Try line-by-line parsing first
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || !strings.HasPrefix(line, "{") {
			continue
		}

		var msg map[string]interface{}
		if err := json.Unmarshal([]byte(line), &msg); err != nil {
			continue
		}

		// Check if this is our tools/list response (ID 2)
		if id, ok := msg["id"]; ok {
			var idNum float64
			switch v := id.(type) {
			case float64:
				idNum = v
			case int:
				idNum = float64(v)
			default:
				continue
			}

			if idNum == 2 {
				if result, ok := msg["result"].(map[string]interface{}); ok {
					if tools, ok := result["tools"].([]interface{}); ok {
						return tools, nil
					}
				}
			}
		}
	}

	return nil, fmt.Errorf("no valid tools response found in output")
}

// Cache management methods
func (ed *EnhancedDiscovery) getCachedTools(serverID string) *CachedToolData {
	ed.cacheMutex.RLock()
	defer ed.cacheMutex.RUnlock()

	if cached, exists := ed.cache[serverID]; exists {
		// Cache expires after 5 minutes
		if time.Since(cached.Timestamp) < 5*time.Minute {
			return &cached
		}
	}

	return nil
}

func (ed *EnhancedDiscovery) setCachedTools(serverID string, data CachedToolData) {
	ed.cacheMutex.Lock()
	defer ed.cacheMutex.Unlock()
	ed.cache[serverID] = data
}

// Diagnostics methods
func (ed *EnhancedDiscovery) addDiagnostic(serverID, issueType, description, severity, resolution string) {
	ed.diagnostics.mutex.Lock()
	defer ed.diagnostics.mutex.Unlock()

	issue := DiagnosticIssue{
		ServerID:    serverID,
		Type:        issueType,
		Description: description,
		Timestamp:   time.Now(),
		Severity:    severity,
		Resolution:  resolution,
	}

	ed.diagnostics.Issues = append(ed.diagnostics.Issues, issue)
}

func (ed *EnhancedDiscovery) getDiagnostics() []DiagnosticIssue {
	ed.diagnostics.mutex.RLock()
	defer ed.diagnostics.mutex.RUnlock()

	return ed.diagnostics.Issues
}

func (ed *EnhancedDiscovery) getRunningServers() []map[string]interface{} {
	// Call the orchestrator API to get server list
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	client := &http.Client{Timeout: 15 * time.Second}
	req, err := http.NewRequestWithContext(ctx, "GET", ed.orchestratorURL+"/api/servers", nil)
	if err != nil {
		ed.addDiagnostic("orchestrator", "api_request_failed",
			fmt.Sprintf("Failed to create API request: %v", err), "error",
			"Check if orchestrator is running and accessible")
		return []map[string]interface{}{}
	}

	resp, err := client.Do(req)
	if err != nil {
		ed.addDiagnostic("orchestrator", "api_connection_failed",
			fmt.Sprintf("Failed to connect to orchestrator API: %v", err), "error",
			"Start the MCP Orchestrator service")
		return []map[string]interface{}{}
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		ed.addDiagnostic("orchestrator", "api_error_response",
			fmt.Sprintf("Orchestrator API returned status %d", resp.StatusCode), "error",
			"Check orchestrator logs for errors")
		return []map[string]interface{}{}
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		ed.addDiagnostic("orchestrator", "api_parse_failed",
			fmt.Sprintf("Failed to parse API response: %v", err), "error",
			"Check orchestrator API response format")
		return []map[string]interface{}{}
	}

	servers, ok := result["servers"].([]interface{})
	if !ok {
		ed.addDiagnostic("orchestrator", "unexpected_response",
			"API response does not contain expected servers array", "warning",
			"Check orchestrator API implementation")
		return []map[string]interface{}{}
	}

	// Convert to proper format
	var serverList []map[string]interface{}
	for _, serverData := range servers {
		if server, ok := serverData.(map[string]interface{}); ok {
			serverList = append(serverList, server)
		}
	}

	return serverList
}
