package servers

import (
	"fmt"
	"strings"
	"time"
)

// EnhancedError represents a detailed error with context and suggestions
type EnhancedError struct {
	Type        string    `json:"type"`
	Message     string    `json:"message"`
	Details     string    `json:"details"`
	Context     string    `json:"context"`
	Suggestions []string  `json:"suggestions"`
	Timestamp   time.Time `json:"timestamp"`
	Severity    string    `json:"severity"` // "error", "warning", "info"
}

// ErrorHandler provides enhanced error handling and reporting
type ErrorHandler struct {
	serverID string
	context  string
}

// NewErrorHandler creates a new enhanced error handler
func NewErrorHandler(serverID, context string) *ErrorHandler {
	return &ErrorHandler{
		serverID: serverID,
		context:  context,
	}
}

// HandleInstallationError creates detailed error information for installation failures
func (eh *ErrorHandler) HandleInstallationError(err error, stage string) *EnhancedError {
	errorMsg := err.Error()

	enhancedErr := &EnhancedError{
		Type:      "installation_error",
		Message:   fmt.Sprintf("%s failed for server %s", stage, eh.serverID),
		Details:   errorMsg,
		Context:   eh.context,
		Timestamp: time.Now(),
		Severity:  "error",
	}

	// Add specific suggestions based on error type and stage
	switch stage {
	case "git_clone":
		enhancedErr.Suggestions = eh.getGitCloneSuggestions(errorMsg)
	case "npm_install":
		enhancedErr.Suggestions = eh.getNpmInstallSuggestions(errorMsg)
	case "npm_build":
		enhancedErr.Suggestions = eh.getNpmBuildSuggestions(errorMsg)
	case "python_venv":
		enhancedErr.Suggestions = eh.getPythonVenvSuggestions(errorMsg)
	case "pip_install":
		enhancedErr.Suggestions = eh.getPipInstallSuggestions(errorMsg)
	case "env_file":
		enhancedErr.Suggestions = eh.getEnvFileSuggestions(errorMsg)
	case "validation":
		enhancedErr.Suggestions = eh.getValidationSuggestions(errorMsg)
	default:
		enhancedErr.Suggestions = eh.getGenericSuggestions(errorMsg)
	}

	return enhancedErr
}

// HandleStartupError creates detailed error information for startup failures
func (eh *ErrorHandler) HandleStartupError(err error) *EnhancedError {
	errorMsg := err.Error()

	enhancedErr := &EnhancedError{
		Type:        "startup_error",
		Message:     fmt.Sprintf("Failed to start server %s", eh.serverID),
		Details:     errorMsg,
		Context:     eh.context,
		Timestamp:   time.Now(),
		Severity:    "error",
		Suggestions: eh.getStartupSuggestions(errorMsg),
	}

	return enhancedErr
}

// HandleToolDiscoveryError creates detailed error information for tool discovery failures
func (eh *ErrorHandler) HandleToolDiscoveryError(err error) *EnhancedError {
	errorMsg := err.Error()

	enhancedErr := &EnhancedError{
		Type:        "tool_discovery_error",
		Message:     fmt.Sprintf("Tool discovery failed for server %s", eh.serverID),
		Details:     errorMsg,
		Context:     eh.context,
		Timestamp:   time.Now(),
		Severity:    "warning",
		Suggestions: eh.getToolDiscoverySuggestions(errorMsg),
	}

	return enhancedErr
}

// Git clone error suggestions
func (eh *ErrorHandler) getGitCloneSuggestions(errorMsg string) []string {
	suggestions := []string{}

	if strings.Contains(errorMsg, "not found") || strings.Contains(errorMsg, "does not exist") {
		suggestions = append(suggestions, "Verify the repository URL is correct and accessible")
		suggestions = append(suggestions, "Check if the repository is public or if you have access permissions")
	}

	if strings.Contains(errorMsg, "Permission denied") || strings.Contains(errorMsg, "authentication") {
		suggestions = append(suggestions, "Configure Git authentication (SSH keys or personal access token)")
		suggestions = append(suggestions, "Run: git config --global credential.helper store")
	}

	if strings.Contains(errorMsg, "network") || strings.Contains(errorMsg, "timeout") {
		suggestions = append(suggestions, "Check your internet connection")
		suggestions = append(suggestions, "Try again in a few minutes - the repository server might be temporarily unavailable")
	}

	if len(suggestions) == 0 {
		suggestions = append(suggestions, "Ensure Git is installed and accessible in your PATH")
		suggestions = append(suggestions, "Try running the clone command manually to see detailed error output")
	}

	return suggestions
}

// NPM install error suggestions
func (eh *ErrorHandler) getNpmInstallSuggestions(errorMsg string) []string {
	suggestions := []string{}

	if strings.Contains(errorMsg, "ENOENT") || strings.Contains(errorMsg, "command not found") {
		suggestions = append(suggestions, "Install Node.js and npm from https://nodejs.org/")
		suggestions = append(suggestions, "Ensure npm is in your PATH")
	}

	if strings.Contains(errorMsg, "EACCES") || strings.Contains(errorMsg, "permission denied") {
		suggestions = append(suggestions, "Fix npm permissions: npm config set prefix ~/.npm-global")
		suggestions = append(suggestions, "Or use a Node version manager like nvm")
	}

	if strings.Contains(errorMsg, "network") || strings.Contains(errorMsg, "registry") {
		suggestions = append(suggestions, "Check your internet connection")
		suggestions = append(suggestions, "Clear npm cache: npm cache clean --force")
		suggestions = append(suggestions, "Try different registry: npm config set registry https://registry.npmjs.org/")
	}

	if strings.Contains(errorMsg, "ERESOLVE") || strings.Contains(errorMsg, "dependency") {
		suggestions = append(suggestions, "Try installing with --legacy-peer-deps flag")
		suggestions = append(suggestions, "Update npm: npm install -g npm@latest")
	}

	if len(suggestions) == 0 {
		suggestions = append(suggestions, "Delete node_modules and package-lock.json, then retry")
		suggestions = append(suggestions, "Check if package.json exists and is valid")
	}

	return suggestions
}

// NPM build error suggestions
func (eh *ErrorHandler) getNpmBuildSuggestions(errorMsg string) []string {
	suggestions := []string{}

	if strings.Contains(errorMsg, "script not found") || strings.Contains(errorMsg, "missing script") {
		suggestions = append(suggestions, "Check if 'build' script exists in package.json")
		suggestions = append(suggestions, "Try running: npm run --silent 2>/dev/null || echo 'No build script'")
	}

	if strings.Contains(errorMsg, "TypeScript") || strings.Contains(errorMsg, "tsc") {
		suggestions = append(suggestions, "Install TypeScript: npm install -g typescript")
		suggestions = append(suggestions, "Check tsconfig.json configuration")
	}

	if strings.Contains(errorMsg, "memory") || strings.Contains(errorMsg, "heap") {
		suggestions = append(suggestions, "Increase Node.js memory: export NODE_OPTIONS='--max-old-space-size=4096'")
		suggestions = append(suggestions, "Close other applications to free up memory")
	}

	if len(suggestions) == 0 {
		suggestions = append(suggestions, "Check the build script in package.json for errors")
		suggestions = append(suggestions, "Try building manually with the exact command from package.json")
	}

	return suggestions
}

// Python virtual environment error suggestions
func (eh *ErrorHandler) getPythonVenvSuggestions(errorMsg string) []string {
	suggestions := []string{}

	if strings.Contains(errorMsg, "command not found") || strings.Contains(errorMsg, "No module named venv") {
		suggestions = append(suggestions, "Install Python 3: https://python.org/downloads/")
		suggestions = append(suggestions, "On Ubuntu: sudo apt-get install python3-venv")
		suggestions = append(suggestions, "On macOS: Install Python via Homebrew: brew install python")
	}

	if strings.Contains(errorMsg, "permission denied") {
		suggestions = append(suggestions, "Check write permissions in the installation directory")
		suggestions = append(suggestions, "Run with sudo if necessary (not recommended for development)")
	}

	if len(suggestions) == 0 {
		suggestions = append(suggestions, "Ensure Python 3 is installed and accessible")
		suggestions = append(suggestions, "Try: python3 --version to verify installation")
	}

	return suggestions
}

// Pip install error suggestions
func (eh *ErrorHandler) getPipInstallSuggestions(errorMsg string) []string {
	suggestions := []string{}

	if strings.Contains(errorMsg, "No such file") || strings.Contains(errorMsg, "requirements.txt") {
		suggestions = append(suggestions, "Check if requirements.txt or setup.py exists")
		suggestions = append(suggestions, "Some packages might not have proper Python packaging")
	}

	if strings.Contains(errorMsg, "permission denied") {
		suggestions = append(suggestions, "The virtual environment should handle permissions automatically")
		suggestions = append(suggestions, "Check if the virtual environment was created properly")
	}

	if strings.Contains(errorMsg, "network") || strings.Contains(errorMsg, "timeout") {
		suggestions = append(suggestions, "Check your internet connection")
		suggestions = append(suggestions, "Try using a different PyPI mirror")
	}

	if strings.Contains(errorMsg, "Microsoft Visual C++") || strings.Contains(errorMsg, "compiler") {
		suggestions = append(suggestions, "Install Microsoft Visual C++ Build Tools (Windows)")
		suggestions = append(suggestions, "Try installing pre-compiled wheels: pip install --only-binary=all")
	}

	if len(suggestions) == 0 {
		suggestions = append(suggestions, "Upgrade pip: pip install --upgrade pip")
		suggestions = append(suggestions, "Try installing in verbose mode to see detailed errors")
	}

	return suggestions
}

// Environment file error suggestions
func (eh *ErrorHandler) getEnvFileSuggestions(errorMsg string) []string {
	suggestions := []string{}

	if strings.Contains(errorMsg, "permission denied") {
		suggestions = append(suggestions, "Check write permissions in the server directory")
	}

	if strings.Contains(errorMsg, "No such file") {
		suggestions = append(suggestions, "The server directory might not exist or be accessible")
	}

	suggestions = append(suggestions, "Verify the server installation completed successfully")
	suggestions = append(suggestions, "Check if the server directory exists and is writable")

	return suggestions
}

// Validation error suggestions
func (eh *ErrorHandler) getValidationSuggestions(errorMsg string) []string {
	suggestions := []string{}

	suggestions = append(suggestions, "Run the auto-fix feature to resolve common issues automatically")
	suggestions = append(suggestions, "Check the validation details for specific problems")
	suggestions = append(suggestions, "Verify all required dependencies are installed")
	suggestions = append(suggestions, "Ensure environment variables are configured correctly")

	return suggestions
}

// Startup error suggestions
func (eh *ErrorHandler) getStartupSuggestions(errorMsg string) []string {
	suggestions := []string{}

	if strings.Contains(errorMsg, "port") || strings.Contains(errorMsg, "address") {
		suggestions = append(suggestions, "Check if another service is using the same port")
		suggestions = append(suggestions, "Try changing the server port in configuration")
	}

	if strings.Contains(errorMsg, "permission denied") {
		suggestions = append(suggestions, "Check if the server executable has proper permissions")
		suggestions = append(suggestions, "Verify the installation completed successfully")
	}

	if strings.Contains(errorMsg, "not found") || strings.Contains(errorMsg, "No such file") {
		suggestions = append(suggestions, "Reinstall the server to ensure all files are present")
		suggestions = append(suggestions, "Check if the server was built correctly")
	}

	if strings.Contains(errorMsg, "environment") || strings.Contains(errorMsg, "config") {
		suggestions = append(suggestions, "Verify all required environment variables are set")
		suggestions = append(suggestions, "Check the .env file for correct configuration")
	}

	if len(suggestions) == 0 {
		suggestions = append(suggestions, "Check server logs for more detailed error information")
		suggestions = append(suggestions, "Try reinstalling the server")
		suggestions = append(suggestions, "Verify all dependencies are properly installed")
	}

	return suggestions
}

// Tool discovery error suggestions
func (eh *ErrorHandler) getToolDiscoverySuggestions(errorMsg string) []string {
	suggestions := []string{}

	if strings.Contains(errorMsg, "timeout") {
		suggestions = append(suggestions, "The server might be slow to start or respond")
		suggestions = append(suggestions, "Check if the server is running and accessible")
	}

	if strings.Contains(errorMsg, "connection") || strings.Contains(errorMsg, "network") {
		suggestions = append(suggestions, "Verify the server is running and listening on the correct port")
		suggestions = append(suggestions, "Check firewall settings if applicable")
	}

	if strings.Contains(errorMsg, "parse") || strings.Contains(errorMsg, "json") {
		suggestions = append(suggestions, "The server might not be implementing MCP protocol correctly")
		suggestions = append(suggestions, "Check server logs for MCP protocol errors")
	}

	if len(suggestions) == 0 {
		suggestions = append(suggestions, "Restart the server and try again")
		suggestions = append(suggestions, "Check if the server supports the tools/list MCP method")
		suggestions = append(suggestions, "Verify server implementation follows MCP protocol specification")
	}

	return suggestions
}

// Generic error suggestions
func (eh *ErrorHandler) getGenericSuggestions(errorMsg string) []string {
	suggestions := []string{}

	suggestions = append(suggestions, "Check the detailed error message for specific clues")
	suggestions = append(suggestions, "Try the operation again - it might be a temporary issue")
	suggestions = append(suggestions, "Verify all system requirements are met")
	suggestions = append(suggestions, "Check server logs for additional context")

	return suggestions
}
