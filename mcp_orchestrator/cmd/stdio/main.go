package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"
)

// MCPMessage represents a generic MCP message
type MCPMessage struct {
	ID      interface{} `json:"id,omitempty"`
	Method  string      `json:"method,omitempty"`
	Params  interface{} `json:"params,omitempty"`
	Result  interface{} `json:"result,omitempty"`
	Error   interface{} `json:"error,omitempty"`
	JSONRPC string      `json:"jsonrpc"`
}

// StdioProxy handles stdio communication with Claude Desktop
type StdioProxy struct {
	orchestratorURL   string
	client            *http.Client
	reader            *bufio.Reader
	writer            *bufio.Writer
	enhancedDiscovery *EnhancedDiscovery
}

// NewStdioProxy creates a new stdio proxy
func NewStdioProxy(orchestratorURL string) *StdioProxy {
	return &StdioProxy{
		orchestratorURL:   orchestratorURL,
		client:            &http.Client{Timeout: 60 * time.Second}, // Increased timeout
		reader:            bufio.NewReader(os.Stdin),
		writer:            bufio.NewWriter(os.Stdout),
		enhancedDiscovery: NewEnhancedDiscovery(orchestratorURL),
	}
}

// Start starts the stdio proxy
func (p *StdioProxy) Start() error {
	// Disable logging to stderr to avoid interfering with MCP communication
	log.SetOutput(io.Discard)

	for {
		if err := p.handleMessage(); err != nil {
			if err == io.EOF {
				return nil
			}
			// Send error response and continue
			errorMsg := p.sendErrorResponse(nil, fmt.Sprintf("Error: %v", err))
			p.sendResponse(errorMsg)
			continue
		}
	}
}

// handleMessage handles a single message from stdin
func (p *StdioProxy) handleMessage() error {
	// Read line from stdin
	line, err := p.reader.ReadString('\n')
	if err != nil {
		return err
	}

	// Skip empty lines
	line = strings.TrimSpace(line)
	if line == "" {
		return nil
	}

	// Parse JSON message
	var msg MCPMessage
	if err := json.Unmarshal([]byte(line), &msg); err != nil {
		errorMsg := p.sendErrorResponse(nil, fmt.Sprintf("Invalid JSON: %v", err))
		return p.sendResponse(errorMsg)
	}

	// Route the message
	response := p.routeMessage(msg)

	// Send response only if there is one (notifications don't get responses)
	if response != nil {
		return p.sendResponse(*response)
	}

	return nil
}

// routeMessage routes messages to the orchestrator
func (p *StdioProxy) routeMessage(msg MCPMessage) *MCPMessage {
	// Handle notifications (no response needed)
	if msg.Method == "notifications/initialized" || msg.Method == "notifications/cancelled" {
		return nil // No response for notifications
	}

	// Handle basic MCP methods directly
	switch msg.Method {
	case "initialize":
		response := p.handleInitialize(msg)
		return &response
	case "tools/list":
		response := p.handleToolsList(msg)
		return &response
	case "tools/categories":
		response := p.handleToolsCategories(msg)
		return &response
	case "tools/call":
		response := p.handleToolCall(msg)
		return &response
	case "resources/list":
		response := p.handleResourcesList(msg)
		return &response
	case "prompts/list":
		response := p.handlePromptsList(msg)
		return &response
	default:
		response := p.sendErrorResponse(msg.ID, fmt.Sprintf("Unknown method: %s", msg.Method))
		return &response
	}
}

// handleInitialize handles the MCP initialize request
func (p *StdioProxy) handleInitialize(msg MCPMessage) MCPMessage {
	return MCPMessage{
		ID:      msg.ID,
		JSONRPC: "2.0",
		Result: map[string]interface{}{
			"protocolVersion": "2024-11-05",
			"capabilities": map[string]interface{}{
				"tools": map[string]interface{}{},
			},
			"serverInfo": map[string]interface{}{
				"name":    "MCP Orchestrator",
				"version": "1.0.0",
			},
		},
	}
}

// handleToolsList handles the tools/list request with pagination and filtering
func (p *StdioProxy) handleToolsList(msg MCPMessage) MCPMessage {
	// Check if orchestrator is running
	if !p.isOrchestratorRunning() {
		return p.sendErrorResponse(msg.ID, "MCP Orchestrator is not running")
	}

	// Parse parameters for pagination and filtering
	var limit int = 25 // Balanced default limit for context management
	var offset int = 0
	var category string
	var namePattern string
	var simplified bool = true    // Default to simplified mode
	var ultraMinimal bool = false // Ultra-minimal mode for very large tool sets

	if msg.Params != nil {
		if params, ok := msg.Params.(map[string]interface{}); ok {
			if l, ok := params["limit"].(float64); ok {
				limit = int(l)
			}
			if o, ok := params["offset"].(float64); ok {
				offset = int(o)
			}
			if c, ok := params["category"].(string); ok {
				category = c
			}
			if n, ok := params["name_pattern"].(string); ok {
				namePattern = n
			}
			if s, ok := params["simplified"].(bool); ok {
				simplified = s
			}
			if u, ok := params["ultra_minimal"].(bool); ok {
				ultraMinimal = u
			}
		}
	}

	// Get tools from running servers using enhanced discovery
	allTools, diagnostics := p.enhancedDiscovery.DiscoverToolsWithDiagnostics()

	// Apply filtering
	filteredTools := p.filterTools(allTools, category, namePattern)

	// Intelligent context-aware limit adjustment
	adjustedLimit := p.adjustLimitForContext(limit, len(filteredTools))

	// Apply pagination
	paginatedTools := p.paginateTools(filteredTools, adjustedLimit, offset)

	// Apply schema simplification based on mode
	if ultraMinimal {
		paginatedTools = p.ultraMinimalToolSchemas(paginatedTools)
	} else if simplified {
		paginatedTools = p.simplifyToolSchemas(paginatedTools)
	}

	// Return response with metadata and diagnostics
	return MCPMessage{
		ID:      msg.ID,
		JSONRPC: "2.0",
		Result: map[string]interface{}{
			"tools":       paginatedTools,
			"diagnostics": diagnostics,
			"_meta": map[string]interface{}{
				"total_count":       len(filteredTools),
				"returned_count":    len(paginatedTools),
				"requested_limit":   limit,
				"adjusted_limit":    adjustedLimit,
				"offset":            offset,
				"simplified":        simplified,
				"ultra_minimal":     ultraMinimal,
				"has_more":          offset+adjustedLimit < len(filteredTools),
				"context_optimized": adjustedLimit != limit,
			},
		},
	}
}

// handleToolCall handles the tools/call request
func (p *StdioProxy) handleToolCall(msg MCPMessage) MCPMessage {
	// Check if orchestrator is running first
	if !p.isOrchestratorRunning() {
		return p.sendErrorResponse(msg.ID, "MCP Orchestrator is not running")
	}

	// Forward tool calls to GoHighLevel server
	result := p.forwardToolCall(msg)
	if result != nil {
		// Check if result contains an error
		if resultMap, ok := result.(map[string]interface{}); ok {
			if errorData, hasError := resultMap["error"]; hasError {
				return MCPMessage{
					ID:      msg.ID,
					JSONRPC: "2.0",
					Error:   errorData,
				}
			}
		}

		// Return successful result
		return MCPMessage{
			ID:      msg.ID,
			JSONRPC: "2.0",
			Result:  result,
		}
	}

	// Fallback error with more context
	return p.sendErrorResponse(msg.ID, "Failed to execute tool - GoHighLevel server may not be running or tool not found")
}

// handleResourcesList handles the resources/list request
func (p *StdioProxy) handleResourcesList(msg MCPMessage) MCPMessage {
	return MCPMessage{
		ID:      msg.ID,
		JSONRPC: "2.0",
		Result: map[string]interface{}{
			"resources": []interface{}{},
		},
	}
}

// handlePromptsList handles the prompts/list request
func (p *StdioProxy) handlePromptsList(msg MCPMessage) MCPMessage {
	return MCPMessage{
		ID:      msg.ID,
		JSONRPC: "2.0",
		Result: map[string]interface{}{
			"prompts": []interface{}{},
		},
	}
}

// handleToolsCategories handles the tools/categories request
func (p *StdioProxy) handleToolsCategories(msg MCPMessage) MCPMessage {
	// Check if orchestrator is running
	if !p.isOrchestratorRunning() {
		return p.sendErrorResponse(msg.ID, "MCP Orchestrator is not running")
	}

	// Get all tools from running servers
	allTools := p.getToolsFromServers()

	// Extract unique categories
	categories := make(map[string]int)
	for _, toolData := range allTools {
		tool, ok := toolData.(map[string]interface{})
		if !ok {
			continue
		}

		category, ok := tool["category"].(string)
		if !ok || category == "" {
			category = "uncategorized"
		}

		categories[category]++
	}

	// Convert to array with counts
	var categoryList []interface{}
	for category, count := range categories {
		categoryList = append(categoryList, map[string]interface{}{
			"name":  category,
			"count": count,
		})
	}

	return MCPMessage{
		ID:      msg.ID,
		JSONRPC: "2.0",
		Result: map[string]interface{}{
			"categories":  categoryList,
			"total_tools": len(allTools),
		},
	}
}

// isOrchestratorRunning checks if the orchestrator is running
func (p *StdioProxy) isOrchestratorRunning() bool {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", p.orchestratorURL+"/health", nil)
	if err != nil {
		return false
	}

	resp, err := p.client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()

	return resp.StatusCode == 200
}

// getToolsFromServers gets real tools from all running MCP servers
func (p *StdioProxy) getToolsFromServers() []interface{} {
	// Check which servers are running
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", p.orchestratorURL+"/api/servers", nil)
	if err != nil {
		return []interface{}{}
	}

	resp, err := p.client.Do(req)
	if err != nil {
		return []interface{}{}
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return []interface{}{}
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return []interface{}{}
	}

	servers, ok := result["servers"].([]interface{})
	if !ok {
		return []interface{}{}
	}

	var allTools []interface{}

	// Collect tools from all running servers
	for _, serverData := range servers {
		server, ok := serverData.(map[string]interface{})
		if !ok {
			continue
		}

		status, ok := server["status"].(string)
		if !ok || status != "running" {
			continue
		}

		id, ok := server["id"].(string)
		if !ok {
			continue
		}

		// Get tools based on server type - now dynamic for all servers
		var serverTools []interface{}
		switch id {
		case "gohighlevel":
			serverTools = p.getGoHighLevelTools()
		case "meta-ads":
			serverTools = p.getMetaAdsTools()
		case "google-ads":
			serverTools = p.getGoogleAdsTools()
		case "github":
			serverTools = p.getGenericServerTools(id, "npx", []string{"-y", "@modelcontextprotocol/server-github"})
		case "puppeteer":
			serverTools = p.getGenericServerTools(id, "npx", []string{"-y", "@modelcontextprotocol/server-puppeteer"})
		case "slack":
			serverTools = p.getGenericServerTools(id, "npx", []string{"-y", "@modelcontextprotocol/server-slack"})
		case "gmail":
			serverTools = p.getGenericServerTools(id, "npx", []string{"-y", "@modelcontextprotocol/server-gmail"})
		case "brave-search":
			serverTools = p.getGenericServerTools(id, "npx", []string{"-y", "@modelcontextprotocol/server-brave-search"})
		default:
			// Try to get tools using generic method for any unknown server
			serverTools = p.getGenericServerTools(id, "npx", []string{"-y", "@modelcontextprotocol/server-" + id})
		}

		// Add server information to each tool for routing
		for _, toolData := range serverTools {
			tool, ok := toolData.(map[string]interface{})
			if !ok {
				continue
			}

			// Add server metadata to the tool
			tool["_server_id"] = id
			tool["_server_name"] = server["name"]

			// Set category if not already set
			if tool["category"] == nil || tool["category"] == "" {
				switch id {
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
					tool["category"] = "web_browser"
				default:
					tool["category"] = id
				}
			}

			allTools = append(allTools, tool)
		}
	}

	return allTools
}

// getGoHighLevelTools connects to GoHighLevel server and gets real tools
func (p *StdioProxy) getGoHighLevelTools() []interface{} {
	// Execute the GoHighLevel server and get tools
	ghlPath := "/Users/user/.mcp_orchestrator/gohighlevel"

	// Check if the GoHighLevel server is actually running
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", p.orchestratorURL+"/api/servers", nil)
	if err != nil {
		return []interface{}{}
	}

	resp, err := p.client.Do(req)
	if err != nil {
		return []interface{}{}
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return []interface{}{}
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return []interface{}{}
	}

	servers, ok := result["servers"].([]interface{})
	if !ok {
		return []interface{}{}
	}

	// Find the GoHighLevel server and check if it's running
	ghlFound := false
	for _, serverData := range servers {
		server, ok := serverData.(map[string]interface{})
		if !ok {
			continue
		}

		status, ok := server["status"].(string)
		if !ok {
			continue
		}

		id, ok := server["id"].(string)
		if !ok {
			continue
		}

		if id == "gohighlevel" {
			ghlFound = true
			if status != "running" {
				return []interface{}{}
			}
			break
		}
	}

	if !ghlFound {
		return []interface{}{}
	}

	// Create the MCP messages
	initMsg := MCPMessage{
		ID:      1,
		Method:  "initialize",
		JSONRPC: "2.0",
		Params: map[string]interface{}{
			"protocolVersion": "2024-11-05",
			"capabilities":    map[string]interface{}{},
			"clientInfo": map[string]interface{}{
				"name":    "mcp-orchestrator",
				"version": "1.0.0",
			},
		},
	}

	notifyMsg := MCPMessage{
		Method:  "notifications/initialized",
		JSONRPC: "2.0",
	}

	toolsMsg := MCPMessage{
		ID:      2,
		Method:  "tools/list",
		JSONRPC: "2.0",
		Params:  map[string]interface{}{},
	}

	// Marshal messages
	initData, _ := json.Marshal(initMsg)
	notifyData, _ := json.Marshal(notifyMsg)
	toolsData, _ := json.Marshal(toolsMsg)

	// Combine into input
	input := string(initData) + "\n" + string(notifyData) + "\n" + string(toolsData) + "\n"

	// Execute GoHighLevel server
	ctx2, cancel2 := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel2()

	cmd := exec.CommandContext(ctx2, "node", "dist/server.js")
	cmd.Dir = ghlPath
	cmd.Stdin = strings.NewReader(input)

	output, err := cmd.Output()
	if err != nil {
		return []interface{}{}
	}

	// Convert output to string and find JSON responses
	outputStr := string(output)

	// Look for JSON objects in the output using a more robust approach
	// Split by lines but also check for JSON patterns in the entire output
	lines := strings.Split(outputStr, "\n")

	// Try line-by-line first for smaller responses
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || !strings.HasPrefix(line, "{") {
			continue
		}

		var msg MCPMessage
		if err := json.Unmarshal([]byte(line), &msg); err != nil {
			continue
		}

		// Check if this is our tools/list response
		// Check if ID is 2 (could be float64 or int)
		idMatches := false
		if id, ok := msg.ID.(float64); ok && id == 2 {
			idMatches = true
		} else if id, ok := msg.ID.(int); ok && id == 2 {
			idMatches = true
		}
		if idMatches && msg.Result != nil {
			if result, ok := msg.Result.(map[string]interface{}); ok {
				if tools, ok := result["tools"].([]interface{}); ok {
					return tools
				}
			}
		}
	}

	// If line-by-line didn't work, try to find JSON responses in the entire output
	// Look for patterns like {"result":{"tools":[...],"jsonrpc":"2.0","id":2}
	toolsPatternStart := `"result":{"tools":[`
	toolsPatternEnd := `]},"jsonrpc":"2.0","id":2}`

	startIdx := strings.Index(outputStr, toolsPatternStart)
	if startIdx != -1 {
		// Find the opening { before "result"
		jsonStart := strings.LastIndex(outputStr[:startIdx], "{")
		if jsonStart != -1 {
			endIdx := strings.Index(outputStr[startIdx:], toolsPatternEnd)
			if endIdx != -1 {
				jsonEnd := jsonStart + (startIdx - jsonStart) + endIdx + len(toolsPatternEnd)
				jsonStr := outputStr[jsonStart:jsonEnd]

				var msg MCPMessage
				if err := json.Unmarshal([]byte(jsonStr), &msg); err == nil {
					// Check if ID is 2 (could be float64 or int)
					idMatches := false
					if id, ok := msg.ID.(float64); ok && id == 2 {
						idMatches = true
					} else if id, ok := msg.ID.(int); ok && id == 2 {
						idMatches = true
					}
					if idMatches && msg.Result != nil {
						if result, ok := msg.Result.(map[string]interface{}); ok {
							if tools, ok := result["tools"].([]interface{}); ok {
								return tools
							}
						}
					}
				}
			}
		}
	}

	return []interface{}{}
}

// forwardToolCall forwards tool calls to the appropriate MCP server based on tool name
func (p *StdioProxy) forwardToolCall(msg MCPMessage) interface{} {
	// Get the tool name from the message
	params, ok := msg.Params.(map[string]interface{})
	if !ok {
		return nil
	}

	toolName, ok := params["name"].(string)
	if !ok {
		return nil
	}

	// Find which server this tool belongs to using enhanced discovery (same as tool listing)
	allTools, _ := p.enhancedDiscovery.DiscoverToolsWithDiagnostics()
	var targetServerID string

	for _, toolData := range allTools {
		tool, ok := toolData.(map[string]interface{})
		if !ok {
			continue
		}

		if tool["name"] == toolName {
			if serverID, ok := tool["_server_id"].(string); ok {
				targetServerID = serverID
				break
			}
		}
	}

	if targetServerID == "" {
		return nil
	}

	// Route to the appropriate server
	switch targetServerID {
	case "gohighlevel":
		return p.forwardToGoHighLevel(msg)
	case "meta-ads":
		return p.forwardToMetaAds(msg)
	case "google-ads":
		return p.forwardToGoogleAds(msg)
	case "github":
		return p.forwardToGenericServer(msg, targetServerID, "npx", []string{"-y", "@modelcontextprotocol/server-github"})
	case "puppeteer":
		return p.forwardToGenericServer(msg, targetServerID, "npx", []string{"-y", "@modelcontextprotocol/server-puppeteer"})
	case "slack":
		return p.forwardToGenericServer(msg, targetServerID, "npx", []string{"-y", "@modelcontextprotocol/server-slack"})
	case "gmail":
		return p.forwardToGenericServer(msg, targetServerID, "npx", []string{"-y", "@modelcontextprotocol/server-gmail"})
	case "brave-search":
		return p.forwardToGenericServer(msg, targetServerID, "npx", []string{"-y", "@modelcontextprotocol/server-brave-search"})
	default:
		// Try generic forwarding for any unknown server
		return p.forwardToGenericServer(msg, targetServerID, "npx", []string{"-y", "@modelcontextprotocol/server-" + targetServerID})
	}
}

// forwardToGoHighLevel forwards tool calls to GoHighLevel server
func (p *StdioProxy) forwardToGoHighLevel(msg MCPMessage) interface{} {
	ghlPath := "/Users/user/.mcp_orchestrator/gohighlevel"

	// First, check if the GoHighLevel server is actually running
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", p.orchestratorURL+"/api/servers", nil)
	if err != nil {
		return nil
	}

	resp, err := p.client.Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil
	}

	servers, ok := result["servers"].([]interface{})
	if !ok {
		return nil
	}

	// Check if GoHighLevel server is running
	ghlRunning := false
	for _, serverData := range servers {
		server, ok := serverData.(map[string]interface{})
		if !ok {
			continue
		}

		id, ok := server["id"].(string)
		if !ok || id != "gohighlevel" {
			continue
		}

		status, ok := server["status"].(string)
		if ok && status == "running" {
			ghlRunning = true
			break
		}
	}

	if !ghlRunning {
		return nil
	}

	// Create the MCP messages for the tool call
	initMsg := MCPMessage{
		ID:      1,
		Method:  "initialize",
		JSONRPC: "2.0",
		Params: map[string]interface{}{
			"protocolVersion": "2024-11-05",
			"capabilities":    map[string]interface{}{},
			"clientInfo": map[string]interface{}{
				"name":    "mcp-orchestrator",
				"version": "1.0.0",
			},
		},
	}

	notifyMsg := MCPMessage{
		Method:  "notifications/initialized",
		JSONRPC: "2.0",
	}

	// Use the original message for the tool call
	toolCallMsg := msg
	toolCallMsg.ID = 2

	// Marshal messages
	initData, _ := json.Marshal(initMsg)
	notifyData, _ := json.Marshal(notifyMsg)
	toolCallData, _ := json.Marshal(toolCallMsg)

	// Combine into input
	input := string(initData) + "\n" + string(notifyData) + "\n" + string(toolCallData) + "\n"

	// Execute GoHighLevel server
	ctx2, cancel2 := context.WithTimeout(context.Background(), 50*time.Second)
	defer cancel2()

	cmd := exec.CommandContext(ctx2, "node", "dist/server.js")
	cmd.Dir = ghlPath
	cmd.Stdin = strings.NewReader(input)

	output, err := cmd.Output()
	if err != nil {
		return nil
	}

	// Parse the response with better error handling
	return p.parseToolCallResponse(string(output))
}

// forwardToMetaAds forwards tool calls to Meta Ads server
func (p *StdioProxy) forwardToMetaAds(msg MCPMessage) interface{} {
	metaAdsPath := "/Users/user/.mcp_orchestrator/meta-ads"

	// Check if the Meta Ads server directory exists
	if _, err := os.Stat(metaAdsPath); os.IsNotExist(err) {
		return nil
	}

	// Create the MCP messages for the tool call
	initMsg := MCPMessage{
		ID:      1,
		Method:  "initialize",
		JSONRPC: "2.0",
		Params: map[string]interface{}{
			"protocolVersion": "2024-11-05",
			"capabilities":    map[string]interface{}{},
			"clientInfo": map[string]interface{}{
				"name":    "mcp-orchestrator",
				"version": "1.0.0",
			},
		},
	}

	notifyMsg := MCPMessage{
		Method:  "notifications/initialized",
		JSONRPC: "2.0",
	}

	// Use the original message for the tool call
	toolCallMsg := msg
	toolCallMsg.ID = 2

	// Marshal messages
	initData, _ := json.Marshal(initMsg)
	notifyData, _ := json.Marshal(notifyMsg)
	toolCallData, _ := json.Marshal(toolCallMsg)

	// Combine into input
	input := string(initData) + "\n" + string(notifyData) + "\n" + string(toolCallData) + "\n"

	// Execute Meta Ads server with virtual environment Python
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Second)
	defer cancel()

	pythonPath := metaAdsPath + "/venv/bin/python"
	if _, err := os.Stat(pythonPath); os.IsNotExist(err) {
		// Windows path
		pythonPath = metaAdsPath + "/venv/Scripts/python.exe"
	}

	cmd := exec.CommandContext(ctx, pythonPath, "-m", "meta_ads_mcp")
	cmd.Dir = metaAdsPath
	cmd.Stdin = strings.NewReader(input)

	output, err := cmd.Output()
	if err != nil {
		return nil
	}

	// Parse the response
	return p.parseToolCallResponse(string(output))
}

// forwardToGoogleAds forwards tool calls to Google Ads server
func (p *StdioProxy) forwardToGoogleAds(msg MCPMessage) interface{} {
	googleAdsPath := "/Users/user/.mcp_orchestrator/google-ads"

	// Check if the Google Ads server directory exists
	if _, err := os.Stat(googleAdsPath); os.IsNotExist(err) {
		return nil
	}

	// Create the MCP messages for the tool call
	initMsg := MCPMessage{
		ID:      1,
		Method:  "initialize",
		JSONRPC: "2.0",
		Params: map[string]interface{}{
			"protocolVersion": "2024-11-05",
			"capabilities":    map[string]interface{}{},
			"clientInfo": map[string]interface{}{
				"name":    "mcp-orchestrator",
				"version": "1.0.0",
			},
		},
	}

	notifyMsg := MCPMessage{
		Method:  "notifications/initialized",
		JSONRPC: "2.0",
	}

	// Use the original message for the tool call
	toolCallMsg := msg
	toolCallMsg.ID = 2

	// Marshal messages
	initData, _ := json.Marshal(initMsg)
	notifyData, _ := json.Marshal(notifyMsg)
	toolCallData, _ := json.Marshal(toolCallMsg)

	// Combine into input
	input := string(initData) + "\n" + string(notifyData) + "\n" + string(toolCallData) + "\n"

	// Execute Google Ads server with virtual environment Python
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Second)
	defer cancel()

	pythonPath := googleAdsPath + "/venv/bin/python"
	if _, err := os.Stat(pythonPath); os.IsNotExist(err) {
		// Windows path
		pythonPath = googleAdsPath + "/venv/Scripts/python.exe"
	}

	cmd := exec.CommandContext(ctx, pythonPath, "-m", "mcp_google_ads")
	cmd.Dir = googleAdsPath
	cmd.Stdin = strings.NewReader(input)

	output, err := cmd.Output()
	if err != nil {
		return nil
	}

	// Parse the response with better error handling
	return p.parseToolCallResponse(string(output))
}

// forwardToGenericServer forwards tool calls to generic MCP servers
func (p *StdioProxy) forwardToGenericServer(msg MCPMessage, serverID, command string, args []string) interface{} {
	serverPath := "/Users/user/.mcp_orchestrator/" + serverID

	// Check if the server directory exists
	if _, err := os.Stat(serverPath); os.IsNotExist(err) {
		return nil
	}

	// Create the MCP messages for the tool call
	initMsg := MCPMessage{
		ID:      1,
		Method:  "initialize",
		JSONRPC: "2.0",
		Params: map[string]interface{}{
			"protocolVersion": "2024-11-05",
			"capabilities":    map[string]interface{}{},
			"clientInfo": map[string]interface{}{
				"name":    "mcp-orchestrator",
				"version": "1.0.0",
			},
		},
	}

	notifyMsg := MCPMessage{
		Method:  "notifications/initialized",
		JSONRPC: "2.0",
	}

	// Use the original message for the tool call
	toolCallMsg := msg
	toolCallMsg.ID = 2

	// Marshal messages
	initData, _ := json.Marshal(initMsg)
	notifyData, _ := json.Marshal(notifyMsg)
	toolCallData, _ := json.Marshal(toolCallMsg)

	// Combine into input
	input := string(initData) + "\n" + string(notifyData) + "\n" + string(toolCallData) + "\n"

	// Execute server
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Second)
	defer cancel()

	// Set up environment variables based on server
	env := os.Environ()
	switch serverID {
	case "github":
		env = append(env, "GITHUB_PERSONAL_ACCESS_TOKEN="+os.Getenv("GITHUB_PERSONAL_ACCESS_TOKEN"))
	case "slack":
		env = append(env, "SLACK_BOT_TOKEN="+os.Getenv("SLACK_BOT_TOKEN"))
	case "gmail":
		env = append(env, "GMAIL_CLIENT_ID="+os.Getenv("GMAIL_CLIENT_ID"))
		env = append(env, "GMAIL_CLIENT_SECRET="+os.Getenv("GMAIL_CLIENT_SECRET"))
	case "brave-search":
		env = append(env, "BRAVE_SEARCH_API_KEY="+os.Getenv("BRAVE_SEARCH_API_KEY"))
	}

	cmd := exec.CommandContext(ctx, command, args...)
	cmd.Dir = serverPath
	cmd.Stdin = strings.NewReader(input)
	cmd.Env = env

	output, err := cmd.Output()
	if err != nil {
		return nil
	}

	// Parse the response with better error handling
	return p.parseToolCallResponse(string(output))
}

// parseToolCallResponse parses the response from a tool call
func (p *StdioProxy) parseToolCallResponse(outputStr string) interface{} {
	// Look for JSON objects in the output
	lines := strings.Split(outputStr, "\n")

	// Try line-by-line first
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || !strings.HasPrefix(line, "{") {
			continue
		}

		var msg MCPMessage
		if err := json.Unmarshal([]byte(line), &msg); err != nil {
			continue
		}

		// Check if this is our tool call response (ID 2)
		idMatches := false
		if id, ok := msg.ID.(float64); ok && id == 2 {
			idMatches = true
		} else if id, ok := msg.ID.(int); ok && id == 2 {
			idMatches = true
		}

		if idMatches {
			if msg.Result != nil {
				return msg.Result
			}
			if msg.Error != nil {
				return map[string]interface{}{
					"error": msg.Error,
				}
			}
		}
	}

	return nil
}

// sendResponse sends a response message to stdout
func (p *StdioProxy) sendResponse(msg MCPMessage) error {
	// Ensure JSONRPC version is set
	if msg.JSONRPC == "" {
		msg.JSONRPC = "2.0"
	}

	data, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal response: %v", err)
	}

	// Write to stdout with newline
	if _, err := p.writer.Write(data); err != nil {
		return err
	}
	if err := p.writer.WriteByte('\n'); err != nil {
		return err
	}

	return p.writer.Flush()
}

// sendErrorResponse sends an error response
func (p *StdioProxy) sendErrorResponse(id interface{}, message string) MCPMessage {
	return MCPMessage{
		ID:      id,
		JSONRPC: "2.0",
		Error: map[string]interface{}{
			"code":    -32700,
			"message": message,
		},
	}
}

// filterTools filters tools based on category and name pattern
func (p *StdioProxy) filterTools(tools []interface{}, category, namePattern string) []interface{} {
	if category == "" && namePattern == "" {
		return tools
	}

	var filtered []interface{}
	for _, toolData := range tools {
		tool, ok := toolData.(map[string]interface{})
		if !ok {
			continue
		}

		// Check category filter
		if category != "" {
			toolCategory, ok := tool["category"].(string)
			if !ok || toolCategory != category {
				continue
			}
		}

		// Check name pattern filter
		if namePattern != "" {
			toolName, ok := tool["name"].(string)
			if !ok || !strings.Contains(strings.ToLower(toolName), strings.ToLower(namePattern)) {
				continue
			}
		}

		filtered = append(filtered, tool)
	}

	return filtered
}

// paginateTools applies pagination to the tools list
func (p *StdioProxy) paginateTools(tools []interface{}, limit, offset int) []interface{} {
	if offset >= len(tools) {
		return []interface{}{}
	}

	end := offset + limit
	if end > len(tools) {
		end = len(tools)
	}

	return tools[offset:end]
}

// simplifyToolSchemas returns simplified versions of tool schemas to reduce context size
func (p *StdioProxy) simplifyToolSchemas(tools []interface{}) []interface{} {
	var simplified []interface{}

	for _, toolData := range tools {
		tool, ok := toolData.(map[string]interface{})
		if !ok {
			continue
		}

		// Create simplified version with just essential fields
		simplifiedTool := map[string]interface{}{
			"name":        tool["name"],
			"description": tool["description"],
			"category":    tool["category"],
		}

		// Add simplified input schema
		if inputSchema, ok := tool["inputSchema"].(map[string]interface{}); ok {
			simplifiedSchema := map[string]interface{}{
				"type":       "object",
				"properties": map[string]interface{}{},
			}

			if props, ok := inputSchema["properties"].(map[string]interface{}); ok {
				simplifiedProps := make(map[string]interface{})
				for propName, propData := range props {
					if prop, ok := propData.(map[string]interface{}); ok {
						// Only include type and description for simplified schema
						simplifiedProps[propName] = map[string]interface{}{
							"type":        prop["type"],
							"description": prop["description"],
						}
					}
				}
				simplifiedSchema["properties"] = simplifiedProps
			}

			simplifiedTool["inputSchema"] = simplifiedSchema
		}

		simplified = append(simplified, simplifiedTool)
	}

	return simplified
}

// adjustLimitForContext intelligently adjusts the limit based on total tools and context constraints
func (p *StdioProxy) adjustLimitForContext(requestedLimit, totalTools int) int {
	// If we have a massive number of tools (like GoHighLevel's 253), be more conservative
	if totalTools > 200 {
		// For very large tool sets, cap at 20 to prevent context overflow
		if requestedLimit > 20 {
			return 20
		}
	} else if totalTools > 100 {
		// For moderately large tool sets, cap at 30
		if requestedLimit > 30 {
			return 30
		}
	} else if totalTools > 50 {
		// For medium tool sets, cap at 40
		if requestedLimit > 40 {
			return 40
		}
	}

	// For smaller tool sets, allow the requested limit up to 50
	if requestedLimit > 50 {
		return 50
	}

	return requestedLimit
}

// ultraMinimalToolSchemas returns ultra-minimal tool schemas with only name and description
func (p *StdioProxy) ultraMinimalToolSchemas(tools []interface{}) []interface{} {
	var ultraMinimal []interface{}

	for _, toolData := range tools {
		tool, ok := toolData.(map[string]interface{})
		if !ok {
			continue
		}

		// Ultra-minimal version with only essential fields
		minimalTool := map[string]interface{}{
			"name":        tool["name"],
			"description": tool["description"],
		}

		// Add category if available for grouping
		if category, ok := tool["category"]; ok && category != nil {
			minimalTool["category"] = category
		}

		ultraMinimal = append(ultraMinimal, minimalTool)
	}

	return ultraMinimal
}

// getMetaAdsTools connects to Meta Ads server and gets real tools
func (p *StdioProxy) getMetaAdsTools() []interface{} {
	// Execute the Meta Ads server and get tools
	metaAdsPath := "/Users/user/.mcp_orchestrator/meta-ads"

	// Check if the Meta Ads server directory exists
	if _, err := os.Stat(metaAdsPath); os.IsNotExist(err) {
		return []interface{}{}
	}

	// Create the MCP messages
	initMsg := MCPMessage{
		ID:      1,
		Method:  "initialize",
		JSONRPC: "2.0",
		Params: map[string]interface{}{
			"protocolVersion": "2024-11-05",
			"capabilities":    map[string]interface{}{},
			"clientInfo": map[string]interface{}{
				"name":    "mcp-orchestrator",
				"version": "1.0.0",
			},
		},
	}

	notifyMsg := MCPMessage{
		Method:  "notifications/initialized",
		JSONRPC: "2.0",
	}

	toolsMsg := MCPMessage{
		ID:      2,
		Method:  "tools/list",
		JSONRPC: "2.0",
		Params:  map[string]interface{}{},
	}

	// Marshal messages
	initData, _ := json.Marshal(initMsg)
	notifyData, _ := json.Marshal(notifyMsg)
	toolsData, _ := json.Marshal(toolsMsg)

	// Combine into input
	input := string(initData) + "\n" + string(notifyData) + "\n" + string(toolsData) + "\n"

	// Execute Meta Ads server with virtual environment Python
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()

	pythonPath := metaAdsPath + "/venv/bin/python"
	if _, err := os.Stat(pythonPath); os.IsNotExist(err) {
		// Windows path
		pythonPath = metaAdsPath + "/venv/Scripts/python.exe"
	}

	cmd := exec.CommandContext(ctx, pythonPath, "-m", "meta_ads_mcp")
	cmd.Dir = metaAdsPath
	cmd.Stdin = strings.NewReader(input)

	output, err := cmd.Output()
	if err != nil {
		return []interface{}{}
	}

	// Parse output using same logic as GoHighLevel
	return p.parseToolsFromOutput(string(output))
}

// getGoogleAdsTools connects to Google Ads server and gets real tools
func (p *StdioProxy) getGoogleAdsTools() []interface{} {
	// Execute the Google Ads server and get tools
	googleAdsPath := "/Users/user/.mcp_orchestrator/google-ads"

	// Check if the Google Ads server directory exists
	if _, err := os.Stat(googleAdsPath); os.IsNotExist(err) {
		return []interface{}{}
	}

	// Create the MCP messages
	initMsg := MCPMessage{
		ID:      1,
		Method:  "initialize",
		JSONRPC: "2.0",
		Params: map[string]interface{}{
			"protocolVersion": "2024-11-05",
			"capabilities":    map[string]interface{}{},
			"clientInfo": map[string]interface{}{
				"name":    "mcp-orchestrator",
				"version": "1.0.0",
			},
		},
	}

	notifyMsg := MCPMessage{
		Method:  "notifications/initialized",
		JSONRPC: "2.0",
	}

	toolsMsg := MCPMessage{
		ID:      2,
		Method:  "tools/list",
		JSONRPC: "2.0",
		Params:  map[string]interface{}{},
	}

	// Marshal messages
	initData, _ := json.Marshal(initMsg)
	notifyData, _ := json.Marshal(notifyMsg)
	toolsData, _ := json.Marshal(toolsMsg)

	// Combine into input
	input := string(initData) + "\n" + string(notifyData) + "\n" + string(toolsData) + "\n"

	// Execute Google Ads server with virtual environment Python
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()

	pythonPath := googleAdsPath + "/venv/bin/python"
	if _, err := os.Stat(pythonPath); os.IsNotExist(err) {
		// Windows path
		pythonPath = googleAdsPath + "/venv/Scripts/python.exe"
	}

	cmd := exec.CommandContext(ctx, pythonPath, "-m", "mcp_google_ads")
	cmd.Dir = googleAdsPath
	cmd.Stdin = strings.NewReader(input)

	output, err := cmd.Output()
	if err != nil {
		return []interface{}{}
	}

	// Parse output using same logic as GoHighLevel
	return p.parseToolsFromOutput(string(output))
}

// parseToolsFromOutput extracts tools from MCP server output
func (p *StdioProxy) parseToolsFromOutput(outputStr string) []interface{} {
	// Look for JSON objects in the output using a more robust approach
	// Split by lines but also check for JSON patterns in the entire output
	lines := strings.Split(outputStr, "\n")

	// Try line-by-line first for smaller responses
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || !strings.HasPrefix(line, "{") {
			continue
		}

		var msg MCPMessage
		if err := json.Unmarshal([]byte(line), &msg); err != nil {
			continue
		}

		// Check if this is our tools/list response
		// Check if ID is 2 (could be float64 or int)
		idMatches := false
		if id, ok := msg.ID.(float64); ok && id == 2 {
			idMatches = true
		} else if id, ok := msg.ID.(int); ok && id == 2 {
			idMatches = true
		}
		if idMatches && msg.Result != nil {
			if result, ok := msg.Result.(map[string]interface{}); ok {
				if tools, ok := result["tools"].([]interface{}); ok {
					return tools
				}
			}
		}
	}

	// If line-by-line didn't work, try to find JSON responses in the entire output
	// Look for patterns like {"result":{"tools":[...],"jsonrpc":"2.0","id":2}
	toolsPatternStart := `"result":{"tools":[`
	toolsPatternEnd := `]},"jsonrpc":"2.0","id":2}`

	startIdx := strings.Index(outputStr, toolsPatternStart)
	if startIdx != -1 {
		// Find the opening { before "result"
		jsonStart := strings.LastIndex(outputStr[:startIdx], "{")
		if jsonStart != -1 {
			endIdx := strings.Index(outputStr[startIdx:], toolsPatternEnd)
			if endIdx != -1 {
				jsonEnd := jsonStart + (startIdx - jsonStart) + endIdx + len(toolsPatternEnd)
				jsonStr := outputStr[jsonStart:jsonEnd]

				var msg MCPMessage
				if err := json.Unmarshal([]byte(jsonStr), &msg); err == nil {
					// Check if ID is 2 (could be float64 or int)
					idMatches := false
					if id, ok := msg.ID.(float64); ok && id == 2 {
						idMatches = true
					} else if id, ok := msg.ID.(int); ok && id == 2 {
						idMatches = true
					}
					if idMatches && msg.Result != nil {
						if result, ok := msg.Result.(map[string]interface{}); ok {
							if tools, ok := result["tools"].([]interface{}); ok {
								return tools
							}
						}
					}
				}
			}
		}
	}

	return []interface{}{}
}

// getGenericServerTools connects to generic MCP servers and gets tools
func (p *StdioProxy) getGenericServerTools(serverID, command string, args []string) []interface{} {
	// Get server path
	serverPath := "/Users/user/.mcp_orchestrator/" + serverID

	// Check if server directory exists
	if _, err := os.Stat(serverPath); os.IsNotExist(err) {
		return []interface{}{}
	}

	// Create the MCP messages
	initMsg := MCPMessage{
		ID:      1,
		Method:  "initialize",
		JSONRPC: "2.0",
		Params: map[string]interface{}{
			"protocolVersion": "2024-11-05",
			"capabilities":    map[string]interface{}{},
			"clientInfo": map[string]interface{}{
				"name":    "mcp-orchestrator",
				"version": "1.0.0",
			},
		},
	}

	notifyMsg := MCPMessage{
		Method:  "notifications/initialized",
		JSONRPC: "2.0",
	}

	toolsMsg := MCPMessage{
		ID:      2,
		Method:  "tools/list",
		JSONRPC: "2.0",
		Params:  map[string]interface{}{},
	}

	// Marshal messages
	initData, _ := json.Marshal(initMsg)
	notifyData, _ := json.Marshal(notifyMsg)
	toolsData, _ := json.Marshal(toolsMsg)

	// Combine into input
	input := string(initData) + "\n" + string(notifyData) + "\n" + string(toolsData) + "\n"

	// Execute server
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()

	// Set up environment variables based on server
	env := os.Environ()
	switch serverID {
	case "github":
		env = append(env, "GITHUB_PERSONAL_ACCESS_TOKEN="+os.Getenv("GITHUB_PERSONAL_ACCESS_TOKEN"))
	case "slack":
		env = append(env, "SLACK_BOT_TOKEN="+os.Getenv("SLACK_BOT_TOKEN"))
	case "gmail":
		env = append(env, "GMAIL_CLIENT_ID="+os.Getenv("GMAIL_CLIENT_ID"))
		env = append(env, "GMAIL_CLIENT_SECRET="+os.Getenv("GMAIL_CLIENT_SECRET"))
	case "brave-search":
		env = append(env, "BRAVE_SEARCH_API_KEY="+os.Getenv("BRAVE_SEARCH_API_KEY"))
	}

	cmd := exec.CommandContext(ctx, command, args...)
	cmd.Dir = serverPath
	cmd.Stdin = strings.NewReader(input)
	cmd.Env = env

	output, err := cmd.Output()
	if err != nil {
		return []interface{}{}
	}

	// Parse output using the existing parser
	return p.parseToolsFromOutput(string(output))
}

func main() {
	// Create stdio proxy
	proxy := NewStdioProxy("http://localhost:8080")

	// Start the proxy
	if err := proxy.Start(); err != nil {
		os.Exit(1)
	}
}
