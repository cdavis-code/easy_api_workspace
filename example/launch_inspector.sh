#!/bin/bash
# Launch MCP Inspector with the easy_api stdio server
# Usage: ./launch_inspector.sh

echo "🔍 Launching MCP Inspector for easy_api code mode testing..."
echo ""

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js is required but not installed."
    echo "   Install from: https://nodejs.org/"
    exit 1
fi

# Check if Dart is available
if ! command -v dart &> /dev/null; then
    echo "❌ Error: Dart SDK is required but not installed."
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "📁 Working directory: $SCRIPT_DIR"
echo ""

# Clean up any existing data files
if [ -f "$SCRIPT_DIR/users.json" ] || [ -f "$SCRIPT_DIR/todos.json" ]; then
    echo "🗑️  Cleaning up existing data files..."
    rm -f "$SCRIPT_DIR/users.json" "$SCRIPT_DIR/todos.json"
fi

echo "🚀 Starting MCP Inspector..."
echo ""
echo "The Inspector will open in your browser at http://localhost:5173"
echo ""
echo "Testing instructions:"
echo "  1. The server should auto-connect with stdio transport"
echo "  2. If not, verify Command: dart"
echo "  3. Arguments: run bin/example.mcp.dart"
echo "  4. Navigate to the 'Tools' tab to see all available tools"
echo "  5. Test 'execute_code' to try code mode!"
echo ""

# Launch MCP Inspector
cd "$SCRIPT_DIR"
npx -y @modelcontextprotocol/inspector dart run bin/example.mcp.dart
