#!/bin/bash

# Enhanced Discovery System Test Runner
# This script runs comprehensive tests to verify the enhanced discovery system

set -e

echo "🚀 Enhanced Discovery System Test Runner"
echo "=========================================="

# Check if orchestrator is running
ORCHESTRATOR_URL="http://localhost:8080"
echo "Checking if orchestrator is running at $ORCHESTRATOR_URL..."

if curl -s "$ORCHESTRATOR_URL/health" > /dev/null 2>&1; then
    echo "✅ Orchestrator is running"
else
    echo "❌ Orchestrator is not running at $ORCHESTRATOR_URL"
    echo "Please start the orchestrator first:"
    echo "  cd mcp_orchestrator && go run main.go"
    exit 1
fi

# Build and run the test suite
echo ""
echo "Building test suite..."
cd "$(dirname "$0")"

# Ensure Go is available
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed or not in PATH"
    exit 1
fi

# Build the test executable
go build -o test_enhanced_discovery test_enhanced_discovery.go

if [ $? -ne 0 ]; then
    echo "❌ Failed to build test suite"
    exit 1
fi

echo "✅ Test suite built successfully"

# Run the tests
echo ""
echo "Running enhanced discovery tests..."
echo ""

./test_enhanced_discovery "$ORCHESTRATOR_URL"

# Cleanup
echo ""
echo "Cleaning up..."
rm -f test_enhanced_discovery

echo "✅ Test run completed!" 