#!/bin/bash

# Test install.sh functionality

echo "=== Testing install.sh functionality ==="
echo

# Create a temporary directory for testing
TEST_DIR="/tmp/claude_install_test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# Mock the Claude config directory
export HOME="$TEST_DIR"
CONFIG_PATH="$TEST_DIR/Library/Application Support/Claude/claude_desktop_config.json"
mkdir -p "$(dirname "$CONFIG_PATH")"

echo "Test 1: Fresh installation"
echo "--------------------------"
./install.sh
echo

echo "Test 2: Attempt reinstall without --force"
echo "------------------------------------------"
./install.sh
echo

echo "Test 3: Create config with existing mcpServers"
echo "-----------------------------------------------"
cat > "$CONFIG_PATH" <<EOF
{
  "mcpServers": {
    "existing-server": {
      "command": "node",
      "args": ["existing.js"]
    }
  }
}
EOF
echo "Created config with existing server:"
cat "$CONFIG_PATH"
echo

echo "Test 4: Install alongside existing server"
echo "------------------------------------------"
./install.sh --force
echo
echo "Final config:"
cat "$CONFIG_PATH"
echo

# Cleanup
rm -rf "$TEST_DIR"
echo
echo "✅ All tests completed!"