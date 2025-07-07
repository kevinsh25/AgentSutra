#!/bin/bash

# Build script for MCP Orchestrator
# This builds the Go binaries that are excluded from version control

set -e

echo "Building MCP Orchestrator binaries..."

# Change to the Go module directory
cd mcp_orchestrator

# Build the main orchestrator
echo "Building main orchestrator..."
go build -o bin/mcp-orchestrator main.go

# Build the stdio proxy
echo "Building stdio proxy..."
cd cmd/stdio
go build -o mcp-orchestrator-stdio main.go enhanced_discovery.go
mv mcp-orchestrator-stdio ../../bin/
cd ../..

echo "✅ Build complete!"
echo "Binaries created:"
echo "  - mcp_orchestrator/bin/mcp-orchestrator"
echo "  - mcp_orchestrator/bin/mcp-orchestrator-stdio"
echo ""
echo "To use:"
echo "  1. Run ./mcp_orchestrator/bin/mcp-orchestrator to start the web UI"
echo "  2. Add mcp_orchestrator/bin/mcp-orchestrator-stdio to your Claude Desktop config" 