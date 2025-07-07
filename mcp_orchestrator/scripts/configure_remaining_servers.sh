#!/bin/bash

# 🔧 Configure Remaining MCP Servers
# This script sets up configuration files for Slack, Google Maps, Gmail, Notion, and Stripe servers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MCP_DIR="$HOME/.mcp_orchestrator"
SERVERS_DIR="$MCP_DIR/servers"
CONFIG_DIR="$MCP_DIR/config"

echo -e "${BLUE}🔧 MCP Orchestrator - Server Configuration${NC}"
echo "==============================================="

# Ensure directories exist
mkdir -p "$SERVERS_DIR"
mkdir -p "$CONFIG_DIR"

# ===========================================
# 1. Slack MCP Server Configuration
# ===========================================
echo -e "\n${YELLOW}1. 📱 Configuring Slack MCP Server${NC}"

mkdir -p "$SERVERS_DIR/slack"

# Slack configuration
cat > "$SERVERS_DIR/slack/config.json" << 'EOF'
{
  "server_name": "slack",
  "executable": "npx",
  "args": ["@modelcontextprotocol/server-slack"],
  "env": {
    "SLACK_BOT_TOKEN": "xoxb-your-bot-token-here",
    "SLACK_APP_TOKEN": "xapp-your-app-token-here",
    "SLACK_SIGNING_SECRET": "your-signing-secret-here"
  },
  "features": {
    "channels": {
      "enabled": true,
      "permissions": ["read", "write", "manage"]
    },
    "messages": {
      "enabled": true,
      "permissions": ["read", "write", "delete"]
    },
    "users": {
      "enabled": true,
      "permissions": ["read", "profile"]
    },
    "files": {
      "enabled": true,
      "permissions": ["read", "write", "delete"]
    },
    "reactions": {
      "enabled": true,
      "permissions": ["read", "write"]
    }
  },
  "rate_limits": {
    "requests_per_minute": 100,
    "burst_limit": 20
  }
}
EOF

# Slack setup instructions
cat > "$SERVERS_DIR/slack/README.md" << 'EOF'
# Slack MCP Server Setup

## 1. Install MCP Server
```bash
npm install -g @modelcontextprotocol/server-slack
```

## 2. Create Slack App
1. Go to https://api.slack.com/apps
2. Click "Create New App" → "From scratch"
3. Enter app name: "MCP Orchestrator"
4. Select your workspace
5. Click "Create App"

## 3. Configure Bot Permissions
1. Go to "OAuth & Permissions"
2. Add these Bot Token Scopes:
   - channels:read
   - channels:write
   - channels:manage
   - chat:write
   - chat:write.public
   - files:read
   - files:write
   - reactions:read
   - reactions:write
   - users:read
   - users.profile:read

## 4. Install App to Workspace
1. Go to "Install App" in sidebar
2. Click "Install to Workspace"
3. Authorize the app

## 5. Get API Keys
1. **Bot User OAuth Token**: Settings → Install App → Bot User OAuth Token
2. **Signing Secret**: Settings → Basic Information → Signing Secret

## 6. Configure Environment
Edit config.json and replace:
- `xoxb-your-bot-token-here` with your Bot User OAuth Token
- `your-signing-secret-here` with your Signing Secret

## 7. Available Tools (Estimated 50+ tools)
- **Channel Management**: Create, list, join, leave channels
- **Message Operations**: Send, edit, delete messages
- **File Operations**: Upload, download, share files
- **User Management**: Get user info, set status
- **Reaction Management**: Add, remove reactions
- **Thread Operations**: Reply to threads, get thread history
EOF

echo -e "${GREEN}✅ Slack configuration created${NC}"

# ===========================================
# 2. Google Maps MCP Server Configuration
# ===========================================
echo -e "\n${YELLOW}2. 🗺️ Configuring Google Maps MCP Server${NC}"

mkdir -p "$SERVERS_DIR/googlemaps"

# Google Maps configuration
cat > "$SERVERS_DIR/googlemaps/config.json" << 'EOF'
{
  "server_name": "googlemaps",
  "executable": "npx",
  "args": ["@modelcontextprotocol/server-googlemaps"],
  "env": {
    "GOOGLE_MAPS_API_KEY": "your-google-maps-api-key-here"
  },
  "features": {
    "geocoding": {
      "enabled": true,
      "daily_limit": 40000
    },
    "places": {
      "enabled": true,
      "daily_limit": 150000
    },
    "directions": {
      "enabled": true,
      "daily_limit": 40000
    },
    "distance_matrix": {
      "enabled": true,
      "daily_limit": 100000
    }
  },
  "rate_limits": {
    "requests_per_second": 50,
    "burst_limit": 100
  }
}
EOF

# Google Maps setup instructions
cat > "$SERVERS_DIR/googlemaps/README.md" << 'EOF'
# Google Maps MCP Server Setup

## 1. Install MCP Server
```bash
npm install -g @modelcontextprotocol/server-googlemaps
```

## 2. Create Google Cloud Project
1. Go to https://console.cloud.google.com/
2. Create a new project or select existing
3. Enable billing (required for Maps API)

## 3. Enable APIs
Enable these APIs in Google Cloud Console:
- Maps JavaScript API
- Places API
- Geocoding API
- Directions API
- Distance Matrix API

## 4. Create API Key
1. Go to "Credentials" in Google Cloud Console
2. Click "Create Credentials" → "API key"
3. Restrict the key to the enabled APIs
4. Set application restrictions (optional)

## 5. Configure Environment
Edit config.json and replace:
- `your-google-maps-api-key-here` with your API key

## 6. Available Tools (Estimated 15+ tools)
- **Geocoding**: Convert addresses to coordinates
- **Reverse Geocoding**: Convert coordinates to addresses
- **Place Search**: Find places by text or location
- **Place Details**: Get detailed place information
- **Directions**: Get route directions
- **Distance Matrix**: Calculate distances/durations
EOF

echo -e "${GREEN}✅ Google Maps configuration created${NC}"

# ===========================================
# 3. Gmail MCP Server Configuration
# ===========================================
echo -e "\n${YELLOW}3. 📧 Configuring Gmail MCP Server${NC}"

mkdir -p "$SERVERS_DIR/gmail"

# Gmail configuration
cat > "$SERVERS_DIR/gmail/config.json" << 'EOF'
{
  "server_name": "gmail",
  "executable": "npx",
  "args": ["@modelcontextprotocol/server-gmail"],
  "env": {
    "GMAIL_CLIENT_ID": "your-gmail-client-id-here",
    "GMAIL_CLIENT_SECRET": "your-gmail-client-secret-here",
    "GMAIL_REFRESH_TOKEN": "your-gmail-refresh-token-here"
  },
  "features": {
    "email_read": {
      "enabled": true,
      "permissions": ["read", "metadata"]
    },
    "email_send": {
      "enabled": true,
      "permissions": ["send", "compose"]
    },
    "email_manage": {
      "enabled": true,
      "permissions": ["modify", "delete"]
    },
    "labels": {
      "enabled": true,
      "permissions": ["read", "create", "modify", "delete"]
    }
  },
  "rate_limits": {
    "requests_per_second": 10,
    "daily_limit": 1000000
  }
}
EOF

# Gmail setup instructions
cat > "$SERVERS_DIR/gmail/README.md" << 'EOF'
# Gmail MCP Server Setup

## 1. Install MCP Server
```bash
npm install -g @modelcontextprotocol/server-gmail
```

## 2. Create Google Cloud Project
1. Go to https://console.cloud.google.com/
2. Create a new project or select existing
3. Enable the Gmail API

## 3. Create OAuth 2.0 Credentials
1. Go to "Credentials" in Google Cloud Console
2. Click "Create Credentials" → "OAuth 2.0 Client IDs"
3. Choose "Desktop application" as application type
4. Download the credentials JSON file

## 4. Configure OAuth Consent Screen
1. Go to "OAuth consent screen"
2. Choose "External" user type
3. Fill required fields:
   - App name: "MCP Orchestrator"
   - User support email: your email
   - Developer contact: your email
4. Add scopes:
   - https://www.googleapis.com/auth/gmail.readonly
   - https://www.googleapis.com/auth/gmail.send
   - https://www.googleapis.com/auth/gmail.modify

## 5. Generate Refresh Token
Use Google's OAuth 2.0 Playground or create a simple script to generate a refresh token.

## 6. Configure Environment
Edit config.json and replace:
- `your-gmail-client-id-here` with your Client ID
- `your-gmail-client-secret-here` with your Client Secret
- `your-gmail-refresh-token-here` with your Refresh Token

## 7. Available Tools (Estimated 25+ tools)
- **Email Management**: Read, send, delete emails
- **Label Management**: Create, modify, delete labels
- **Search**: Advanced email search
- **Attachments**: Download and manage attachments
- **Drafts**: Create and manage drafts
- **Threading**: Handle email threads
EOF

echo -e "${GREEN}✅ Gmail configuration created${NC}"

# ===========================================
# 4. Notion MCP Server Configuration
# ===========================================
echo -e "\n${YELLOW}4. 📔 Configuring Notion MCP Server${NC}"

mkdir -p "$SERVERS_DIR/notion"

# Notion configuration
cat > "$SERVERS_DIR/notion/config.json" << 'EOF'
{
  "server_name": "notion",
  "executable": "npx",
  "args": ["@modelcontextprotocol/server-notion"],
  "env": {
    "NOTION_API_KEY": "secret_your-notion-integration-token-here"
  },
  "features": {
    "pages": {
      "enabled": true,
      "permissions": ["read", "create", "update", "delete"]
    },
    "databases": {
      "enabled": true,
      "permissions": ["read", "create", "update", "query"]
    },
    "blocks": {
      "enabled": true,
      "permissions": ["read", "create", "update", "delete"]
    },
    "search": {
      "enabled": true,
      "permissions": ["search"]
    }
  },
  "rate_limits": {
    "requests_per_second": 3,
    "burst_limit": 10
  }
}
EOF

# Notion setup instructions
cat > "$SERVERS_DIR/notion/README.md" << 'EOF'
# Notion MCP Server Setup

## 1. Install MCP Server
```bash
npm install -g @modelcontextprotocol/server-notion
```

## 2. Create Notion Integration
1. Go to https://www.notion.so/my-integrations
2. Click "New integration"
3. Fill in details:
   - Name: "MCP Orchestrator"
   - Description: "AI-powered automation and management"
4. Select capabilities:
   - Read content
   - Update content
   - Insert content
   - Read user information

## 3. Get Integration Token
1. After creating integration, copy the "Internal Integration Token"
2. This is your NOTION_API_KEY

## 4. Share Pages/Databases
1. Go to the Notion page/database you want to access
2. Click "Share" in the top right
3. Click "Invite" and select your integration
4. Give appropriate permissions

## 5. Configure Environment
Edit config.json and replace:
- `secret_your-notion-integration-token-here` with your Integration Token

## 6. Available Tools (Estimated 30+ tools)
- **Page Management**: Create, read, update, delete pages
- **Database Operations**: Query, create, update databases
- **Block Operations**: Manage content blocks
- **Search**: Search across workspace
- **Comments**: Add and read comments
- **Properties**: Manage page properties
EOF

echo -e "${GREEN}✅ Notion configuration created${NC}"

# ===========================================
# 5. Stripe MCP Server Configuration
# ===========================================
echo -e "\n${YELLOW}5. 💳 Configuring Stripe MCP Server${NC}"

mkdir -p "$SERVERS_DIR/stripe"

# Stripe configuration
cat > "$SERVERS_DIR/stripe/config.json" << 'EOF'
{
  "server_name": "stripe",
  "executable": "npx",
  "args": ["@modelcontextprotocol/server-stripe"],
  "env": {
    "STRIPE_SECRET_KEY": "sk_test_your-stripe-secret-key-here",
    "STRIPE_WEBHOOK_SECRET": "whsec_your-webhook-secret-here"
  },
  "features": {
    "customers": {
      "enabled": true,
      "permissions": ["read", "create", "update", "delete"]
    },
    "products": {
      "enabled": true,
      "permissions": ["read", "create", "update", "delete"]
    },
    "subscriptions": {
      "enabled": true,
      "permissions": ["read", "create", "update", "cancel"]
    },
    "payments": {
      "enabled": true,
      "permissions": ["read", "create", "capture", "refund"]
    }
  },
  "rate_limits": {
    "requests_per_second": 25,
    "burst_limit": 50
  }
}
EOF

# Stripe setup instructions
cat > "$SERVERS_DIR/stripe/README.md" << 'EOF'
# Stripe MCP Server Setup

## 1. Install MCP Server
```bash
npm install -g @modelcontextprotocol/server-stripe
```

## 2. Create Stripe Account
1. Go to https://stripe.com/
2. Sign up for an account
3. Complete account verification

## 3. Get API Keys
1. Go to https://dashboard.stripe.com/apikeys
2. Copy your keys:
   - **Secret key**: sk_test_... (for testing) or sk_live_... (for production)

## 4. Configure Environment
Edit config.json and replace:
- `sk_test_your-stripe-secret-key-here` with your Secret Key

## 5. Available Tools (Estimated 40+ tools)
- **Customer Management**: Create, read, update, delete customers
- **Product Management**: Manage products and prices
- **Subscription Management**: Create and manage subscriptions
- **Payment Processing**: Handle payments and refunds
- **Invoice Management**: Create and manage invoices
- **Analytics**: Access financial reports
EOF

echo -e "${GREEN}✅ Stripe configuration created${NC}"

# ===========================================
# 6. Update Orchestrator Configuration
# ===========================================
echo -e "\n${YELLOW}6. 🔄 Updating Orchestrator Configuration${NC}"

# Update main orchestrator config to include new servers
cat > "$MCP_DIR/config.json" << 'EOF'
{
  "servers": {
    "gohighlevel": {
      "command": "~/.mcp_orchestrator/servers/gohighlevel/server",
      "args": [],
      "env": {
        "GHL_API_KEY": "pit-4d70abe4-5a44-48f1-a485-bf0c2f28fda3",
        "GHL_LOCATION_ID": "ZOaXmBfvz6jJhBCHu3iN"
      },
      "category": "CRM & Marketing",
      "enabled": true
    },
    "github": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "github_pat_11BH4PRGI0PcJZe6tWnVhJ_your_actual_token_here"
      },
      "category": "Development",
      "enabled": true
    },
    "puppeteer": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-puppeteer"],
      "env": {},
      "category": "Browser Automation",
      "enabled": true
    },
    "brave_search": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": "BSAhPx-yBOE4UJGcfxvwfBbN1pZGEgzc4"
      },
      "category": "Search",
      "enabled": true
    },
    "slack": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "xoxb-your-bot-token-here",
        "SLACK_SIGNING_SECRET": "your-signing-secret-here"
      },
      "category": "Communication",
      "enabled": false
    },
    "googlemaps": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-googlemaps"],
      "env": {
        "GOOGLE_MAPS_API_KEY": "your-google-maps-api-key-here"
      },
      "category": "Location Services",
      "enabled": false
    },
    "gmail": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-gmail"],
      "env": {
        "GMAIL_CLIENT_ID": "your-gmail-client-id-here",
        "GMAIL_CLIENT_SECRET": "your-gmail-client-secret-here",
        "GMAIL_REFRESH_TOKEN": "your-gmail-refresh-token-here"
      },
      "category": "Email",
      "enabled": false
    },
    "notion": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-notion"],
      "env": {
        "NOTION_API_KEY": "secret_your-notion-integration-token-here"
      },
      "category": "Productivity",
      "enabled": false
    },
    "stripe": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-stripe"],
      "env": {
        "STRIPE_SECRET_KEY": "sk_test_your-stripe-secret-key-here"
      },
      "category": "Payments",
      "enabled": false
    }
  },
  "profiles": {
    "development": {
      "servers": ["github", "puppeteer", "brave_search"],
      "description": "Development and testing tools"
    },
    "marketing": {
      "servers": ["gohighlevel", "slack", "brave_search"],
      "description": "CRM and marketing automation"
    },
    "productivity": {
      "servers": ["gmail", "notion", "googlemaps", "brave_search"],
      "description": "Productivity and organization tools"
    },
    "business": {
      "servers": ["stripe", "gmail", "slack", "notion"],
      "description": "Business operations and finance"
    },
    "all_tools": {
      "servers": ["gohighlevel", "github", "puppeteer", "brave_search", "slack", "googlemaps", "gmail", "notion", "stripe"],
      "description": "All available tools and servers"
    }
  },
  "active_profile": "marketing",
  "performance": {
    "cache_enabled": true,
    "cache_ttl": 300,
    "connection_pool_size": 10,
    "request_timeout": 30
  },
  "analytics": {
    "enabled": true,
    "retention_days": 30
  }
}
EOF

echo -e "${GREEN}✅ Orchestrator configuration updated${NC}"

# ===========================================
# 7. Create Setup Summary
# ===========================================
echo -e "\n${YELLOW}7. 📋 Creating Setup Summary${NC}"

cat > "$MCP_DIR/SETUP_SUMMARY.md" << 'EOF'
# 🔧 MCP Orchestrator - Server Setup Summary

## ✅ Currently Active (286 tools)
- **GoHighLevel**: 253 tools - CRM, Marketing, Calendar, Messaging
- **GitHub**: 26 tools - Repository management, Issues, Pull Requests
- **Puppeteer**: 7 tools - Browser automation, Screenshots
- **Brave Search**: 8 tools - Web search, Real-time information

## ⚠️ Ready for Configuration (200+ additional tools)
Complete these servers by following their respective README files:

### 1. Slack (Est. 50+ tools)
📁 `~/.mcp_orchestrator/servers/slack/README.md`
- Create Slack App with bot permissions
- Get Bot Token and Signing Secret
- Update config.json with credentials
- Enable in orchestrator config

### 2. Google Maps (Est. 15+ tools)
📁 `~/.mcp_orchestrator/servers/googlemaps/README.md`
- Create Google Cloud Project
- Enable Maps APIs
- Create API key
- Update config.json with API key

### 3. Gmail (Est. 25+ tools)
📁 `~/.mcp_orchestrator/servers/gmail/README.md`
- Create Google OAuth app
- Generate refresh token
- Update config.json with OAuth credentials

### 4. Notion (Est. 30+ tools)
📁 `~/.mcp_orchestrator/servers/notion/README.md`
- Create Notion integration
- Share databases/pages with integration
- Update config.json with integration token

### 5. Stripe (Est. 40+ tools)
📁 `~/.mcp_orchestrator/servers/stripe/README.md`
- Create Stripe account
- Get API keys
- Update config.json with API keys

## 🚀 After Configuration
- **Total Tools**: 500+ tools across 9 servers
- **Categories**: CRM, Development, Communication, Email, Productivity, Payments, Location, Search, Automation

## 📊 Profile Options
- **Development**: GitHub + Puppeteer + Brave Search (36 tools)
- **Marketing**: GoHighLevel + Slack + Brave Search (311+ tools)
- **Productivity**: Gmail + Notion + Google Maps + Brave Search (78+ tools)
- **Business**: Stripe + Gmail + Slack + Notion (145+ tools)
- **All Tools**: All servers enabled (500+ tools)

## 🔧 Configuration Steps
1. Choose which servers you need
2. Follow README instructions for each server
3. Install required npm packages
4. Configure API keys/tokens
5. Enable servers in `~/.mcp_orchestrator/config.json`
6. Restart orchestrator
7. Test new tools

## 🎯 Quick Start Commands
```bash
# Install all MCP servers
npm install -g @modelcontextprotocol/server-slack
npm install -g @modelcontextprotocol/server-googlemaps  
npm install -g @modelcontextprotocol/server-gmail
npm install -g @modelcontextprotocol/server-notion
npm install -g @modelcontextprotocol/server-stripe

# Test configuration
curl http://localhost:8080/api/servers

# Check tools after configuration
curl http://localhost:8080/api/tools
```

## 🔒 Security Notes
- Use test/sandbox API keys during setup
- Store production keys securely
- Regularly rotate API keys
- Monitor API usage and costs
- Enable only needed servers for better performance
EOF

echo -e "${GREEN}✅ Setup summary created${NC}"

# ===========================================
# Final Summary
# ===========================================
echo -e "\n${BLUE}🎉 Configuration Complete!${NC}"
echo "==============================="
echo -e "${GREEN}✅ 5 new MCP servers configured${NC}"
echo -e "${GREEN}✅ Configuration files created${NC}"
echo -e "${GREEN}✅ Setup documentation provided${NC}"
echo -e "${GREEN}✅ Orchestrator config updated${NC}"

echo -e "\n${YELLOW}📋 Next Steps:${NC}"
echo "1. Review setup summary: $MCP_DIR/SETUP_SUMMARY.md"
echo "2. Install required npm packages for servers you need"
echo "3. Configure API keys following individual README files"
echo "4. Enable servers in orchestrator config"
echo "5. Restart orchestrator to load new servers"

echo -e "\n${BLUE}📁 Configuration Files:${NC}"
echo "- Main config: $MCP_DIR/config.json"
echo "- Server configs: $MCP_DIR/servers/*/config.json"
echo "- Setup guide: $MCP_DIR/SETUP_SUMMARY.md"

echo -e "\n${BLUE}🎯 Potential Tool Count After Setup:${NC}"
echo "- Current: 286 tools (4 servers)"
echo "- After full setup: 500+ tools (9 servers)"
echo "- 75% increase in available functionality"

echo -e "\n${GREEN}Setup complete! 🚀${NC}"
echo "Follow the README files in each server directory to complete configuration."
EOF 