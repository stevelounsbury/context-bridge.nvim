#!/bin/bash
#
# Manual test setup for context-bridge.nvim
#
# Creates a tmux session with neovim and an agent pane for interactive testing.
# Use this to manually verify plugin behavior.
#

set -e

SESSION_NAME="cb-manual-test"
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$TEST_DIR")"
TEST_FILE="$TEST_DIR/fixtures/sample.lua"
SCRATCHPAD="/tmp/context-bridge-manual-test"

# Kill existing session if any
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# Create scratchpad
mkdir -p "$SCRATCHPAD"
mkdir -p "$TEST_DIR/fixtures"

# Create test fixture
cat > "$TEST_FILE" << 'FIXTURE'
-- Sample Lua file for testing context-bridge
local M = {}

function M.hello()
  return "Hello, World!"
end

function M.add(a, b)
  return a + b
end

function M.greet(name)
  return string.format("Hello, %s!", name)
end

return M
FIXTURE

# Create minimal nvim config
cat > "$SCRATCHPAD/init.lua" << NVIMCONFIG
-- Minimal test config for context-bridge
vim.g.mapleader = ","

-- Load context-bridge from the repo
package.path = package.path .. ";$REPO_DIR/?.lua"
require('context-bridge').setup()

-- Helper to reload plugin during development
vim.api.nvim_create_user_command('ReloadContextBridge', function()
  package.loaded['context-bridge'] = nil
  require('context-bridge').setup()
  print('Context Bridge reloaded!')
end, {})
NVIMCONFIG

echo "=========================================="
echo "Context Bridge Manual Test Environment"
echo "=========================================="
echo
echo "Creating tmux session with:"
echo "  - Left pane: Neovim with test file"
echo "  - Right pane: Agent receiver (your commands appear here)"
echo
echo "Test commands in Neovim:"
echo "  ,cc  - Send visual selection"
echo "  ,cl  - Send current line"
echo "  ,cf  - Send file metadata"
echo "  :ContextBridgeSendFileContents - Send full file"
echo "  :ReloadContextBridge - Reload plugin after changes"
echo
echo "Press Escape during context prompt to test cancellation"
echo
echo "=========================================="
echo

# Create session with neovim
tmux new-session -d -s "$SESSION_NAME" -x 160 -y 50 \
  "nvim -u $SCRATCHPAD/init.lua $TEST_FILE; read -p 'Press enter to exit...'"

# Split and create agent pane
tmux split-window -h -t "$SESSION_NAME" \
  "echo '=== Agent Pane ===' && echo 'Commands from neovim will appear below:' && echo && cat; read -p 'Press enter to exit...'"

# Make panes equal size
tmux select-layout -t "$SESSION_NAME" even-horizontal

# Attach to session
tmux attach-session -t "$SESSION_NAME"
