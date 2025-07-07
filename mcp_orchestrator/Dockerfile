# 🐳 MCP Orchestrator Docker Container
# Multi-stage build for optimal image size and security

# ==========================================
# Build Stage
# ==========================================
FROM golang:1.21-alpine AS builder

# Install necessary packages
RUN apk add --no-cache git ca-certificates tzdata

# Create non-root user for security
RUN adduser -D -g '' mcpuser

# Set working directory
WORKDIR /app

# Copy go.mod and go.sum for dependency caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download
RUN go mod verify

# Copy source code
COPY . .

# Build the application with optimizations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o mcp-orchestrator \
    cmd/stdio/main.go

# ==========================================
# Runtime Stage
# ==========================================
FROM scratch AS runtime

# Import from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/passwd /etc/passwd

# Copy the binary
COPY --from=builder /app/mcp-orchestrator /mcp-orchestrator

# Create necessary directories
COPY --from=builder --chown=mcpuser:mcpuser /tmp /tmp

# Switch to non-root user
USER mcpuser

# Set environment variables
ENV PORT=3000
ENV UI_PORT=8080
ENV MCP_ORCHESTRATOR_CONFIG_DIR=/data
ENV MCP_ORCHESTRATOR_DATA_DIR=/data

# Expose ports
EXPOSE 3000 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/mcp-orchestrator", "--health-check"]

# Set entrypoint
ENTRYPOINT ["/mcp-orchestrator"]
CMD ["--config-dir=/data"]

# Metadata
LABEL maintainer="MCP Orchestrator Team"
LABEL version="1.0.0"
LABEL description="Enterprise MCP Server Orchestrator"
LABEL org.opencontainers.image.title="MCP Orchestrator"
LABEL org.opencontainers.image.description="Enterprise-grade MCP server orchestrator with analytics and performance optimization"
LABEL org.opencontainers.image.vendor="MCP Orchestrator"
LABEL org.opencontainers.image.licenses="MIT" 