#!/bin/bash
#
# Integration test for context-bridge.nvim
#
# Usage:
#   ./integration_test.sh           # Run tests automatically
#   ./integration_test.sh --watch   # Run tests, then attach to inspect
#   ./integration_test.sh --attach  # Setup only, then attach for manual testing
#   ./integration_test.sh --debug   # Show verbose debug output
#

set -u

# Parse arguments
WATCH_MODE=false
ATTACH_MODE=false
DEBUG_MODE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --watch) WATCH_MODE=true; shift ;;
    --attach) ATTACH_MODE=true; shift ;;
    --debug) DEBUG_MODE=true; shift ;;
    *) echo "Usage: $0 [--watch] [--attach] [--debug]"; exit 1 ;;
  esac
done

# Configuration
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$TEST_DIR")"
SCRATCHPAD="/tmp/cb-test-$$"
AGENT_OUTPUT="$SCRATCHPAD/agent_output.txt"

# Create scratchpad early so TMUX_TMPDIR exists
mkdir -p "$SCRATCHPAD"

# Use isolated tmux environment
# TMUX_TMPDIR makes all tmux commands (ours AND the plugin's) use this directory for sockets
export TMUX_TMPDIR="$SCRATCHPAD/tmux"
mkdir -p "$TMUX_TMPDIR"

TMUX_SOCKET="default"  # Use default socket name within our custom tmpdir
SESSION_NAME="test"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((TESTS_FAILED++)); }
log_debug() { [[ "$DEBUG_MODE" == "true" ]] && echo -e "[DEBUG] $1"; }

# Wrapper for tmux commands - TMUX_TMPDIR is already set so no need for -L
T() { tmux "$@"; }

cleanup() {
  log_info "Cleaning up..."
  T kill-server 2>/dev/null || true
  rm -rf "$SCRATCHPAD"
}
trap cleanup EXIT

setup() {
  log_info "Setting up test environment..."
  mkdir -p "$SCRATCHPAD"
  mkdir -p "$TEST_DIR/fixtures"

  # Create test file
  cat > "$TEST_DIR/fixtures/sample.lua" << 'EOF'
-- Test file
local M = {}

function M.hello()
  return "Hello, World!"
end

function M.add(a, b)
  return a + b
end

return M
EOF

  # Create minimal nvim config
  cat > "$SCRATCHPAD/init.lua" << NVIMCONFIG
vim.g.mapleader = ","
package.path = package.path .. ";$REPO_DIR/?.lua"
require('context-bridge').setup()
NVIMCONFIG
}

start_session() {
  log_info "Starting tmux session (socket: $TMUX_SOCKET)"

  # Create session with two panes
  T new-session -d -s "$SESSION_NAME" -x 160 -y 50
  T split-window -h -t "$SESSION_NAME"

  # Get pane IDs
  NVIM_PANE=$(T list-panes -t "$SESSION_NAME" -F '#{pane_id}' | head -1)
  AGENT_PANE=$(T list-panes -t "$SESSION_NAME" -F '#{pane_id}' | tail -1)

  log_info "Neovim pane: $NVIM_PANE, Agent pane: $AGENT_PANE"

  echo ""
  echo "To attach from another terminal:"
  echo "  TMUX_TMPDIR='$TMUX_TMPDIR' tmux attach -t $SESSION_NAME"
  echo ""

  # Create output file and start cat receiver in agent pane
  touch "$AGENT_OUTPUT"
  T send-keys -t "$AGENT_PANE" "cat >> $AGENT_OUTPUT" Enter
  sleep 0.3
  log_debug "Agent pane ready, output file: $AGENT_OUTPUT"

  # Set TMUX_TMPDIR in the pane so plugin's tmux commands use our isolated server
  T send-keys -t "$NVIM_PANE" "export TMUX_TMPDIR='$TMUX_TMPDIR'" Enter
  sleep 0.3

  # Debug: show TMUX env
  T send-keys -t "$NVIM_PANE" 'echo "TMUX=$TMUX"' Enter
  sleep 0.5
  log_debug "Pane contents:"
  T capture-pane -t "$NVIM_PANE" -p | while read line; do log_debug "  $line"; done

  # Start neovim
  T send-keys -t "$NVIM_PANE" "nvim -u $SCRATCHPAD/init.lua $TEST_DIR/fixtures/sample.lua" Enter
  sleep 3

  # Select nvim pane (important for plugin's pane detection)
  T select-pane -t "$NVIM_PANE"

  log_debug "After nvim start:"
  T capture-pane -t "$NVIM_PANE" -p | tail -5 | while read line; do log_debug "  $line"; done

  # Explicitly set the target pane in the plugin (bypasses auto-detection issues in nested tmux)
  log_info "Configuring plugin to use agent pane: $AGENT_PANE"
  N ":ContextBridgeSetPane $AGENT_PANE" Enter
  sleep 0.5

  log_info "Neovim started and configured"
}

# Capture output and clear for next test
get_output() {
  sleep 0.5
  [[ -f "$AGENT_OUTPUT" ]] && cat "$AGENT_OUTPUT"
}

clear_output() {
  : > "$AGENT_OUTPUT" 2>/dev/null || true
  T select-pane -t "$NVIM_PANE"
}

# Send keys to nvim
N() { T send-keys -t "$NVIM_PANE" "$@"; }

#############################################
# Tests
#############################################

test_send_line() {
  ((TESTS_RUN++))
  log_info "Test: Send current line (,cl)"
  clear_output

  N Escape
  N ":4" Enter        # Go to function M.hello() line
  sleep 0.3

  log_debug "Before ,cl - nvim pane:"
  T capture-pane -t "$NVIM_PANE" -p | tail -5 | while read line; do log_debug "  $line"; done

  N ",cl"             # Trigger send line
  sleep 1

  log_debug "After ,cl - nvim pane:"
  T capture-pane -t "$NVIM_PANE" -p | tail -5 | while read line; do log_debug "  $line"; done

  N -l "test question"
  sleep 0.3
  N Enter
  sleep 2

  log_debug "After Enter - nvim pane:"
  T capture-pane -t "$NVIM_PANE" -p | tail -5 | while read line; do log_debug "  $line"; done

  # Debug: Check agent pane directly
  log_debug "Agent pane contents:"
  T capture-pane -t "$AGENT_PANE" -p | tail -10 | while read line; do log_debug "  AGENT: $line"; done

  local output=$(get_output)
  log_debug "Output file contents: '$output'"
  log_debug "Output file size: $(wc -c < "$AGENT_OUTPUT" 2>/dev/null || echo 0)"

  if echo "$output" | grep -q "test question" && echo "$output" | grep -q "M.hello"; then
    log_pass "Send line works"
  else
    log_fail "Send line - expected 'test question' and 'M.hello'"
    echo "Got: $output"
  fi
}

test_send_visual() {
  ((TESTS_RUN++))
  log_info "Test: Send visual selection (,cc)"
  clear_output

  N Escape
  N ":8" Enter        # Go to function M.add line
  sleep 0.3
  N "V2j"             # Visual select 3 lines
  sleep 0.3
  N ",cc"
  sleep 1
  N -l "explain this"
  sleep 0.3
  N Enter
  sleep 2

  local output=$(get_output)
  log_debug "Output: $output"

  if echo "$output" | grep -q "explain this" && echo "$output" | grep -q "M.add"; then
    log_pass "Send visual works"
  else
    log_fail "Send visual - expected 'explain this' and 'M.add'"
    echo "Got: $output"
  fi
}

test_send_file_metadata() {
  ((TESTS_RUN++))
  log_info "Test: Send file metadata (,cf)"
  clear_output

  N Escape
  sleep 0.2
  N ",cf"
  sleep 1
  N -l "about this file"
  sleep 0.3
  N Enter
  sleep 2

  local output=$(get_output)
  log_debug "Output: $output"

  if echo "$output" | grep -q "File:" && echo "$output" | grep -q "Type: lua"; then
    log_pass "Send file metadata works"
  else
    log_fail "Send file metadata - expected 'File:' and 'Type: lua'"
    echo "Got: $output"
  fi
}

test_escape_cancels() {
  ((TESTS_RUN++))
  log_info "Test: Escape cancels"
  clear_output

  N Escape
  N ":4" Enter
  sleep 0.3
  N ",cl"
  sleep 1
  N Escape
  sleep 1

  local output=$(get_output)
  local len=${#output}
  log_debug "Output length: $len"

  if [[ $len -lt 10 ]]; then
    log_pass "Escape cancels (no content sent)"
  else
    log_fail "Escape should cancel but got output"
    echo "Got: $output"
  fi
}

test_send_file_contents() {
  ((TESTS_RUN++))
  log_info "Test: Send file contents"
  clear_output

  N Escape
  sleep 0.2
  N ":ContextBridgeSendFileContents" Enter
  sleep 1
  N -l "review code"
  sleep 0.3
  N Enter
  sleep 2

  local output=$(get_output)
  log_debug "Output: $output"

  if echo "$output" | grep -q "M.hello" && echo "$output" | grep -q "M.add"; then
    log_pass "Send file contents works"
  else
    log_fail "Send file contents - expected both functions"
    echo "Got: $output"
  fi
}

test_empty_context() {
  ((TESTS_RUN++))
  log_info "Test: Empty context still sends"
  clear_output

  N Escape
  N ":5" Enter
  sleep 0.3
  N ",cl"
  sleep 1
  N Enter   # Empty context
  sleep 2

  local output=$(get_output)
  log_debug "Output: $output"

  if echo "$output" | grep -q "Hello"; then
    log_pass "Empty context sends code"
  else
    log_fail "Empty context - expected code to be sent"
    echo "Got: $output"
  fi
}

#############################################
# Main
#############################################

main() {
  echo "========================================"
  echo "Context Bridge Integration Tests"
  echo "========================================"

  setup
  start_session

  if [[ "$ATTACH_MODE" == "true" ]]; then
    echo ""
    echo "Attach mode - test manually, then exit nvim"
    trap - EXIT  # Don't cleanup on exit
    T attach-session -t "$SESSION_NAME"
    exit 0
  fi

  if [[ "$WATCH_MODE" == "true" ]]; then
    echo ""
    read -p "Press Enter when ready to run tests (attach first if you want to watch)..."
  fi

  # Run tests
  test_send_line
  test_send_visual
  test_send_file_metadata
  test_escape_cancels
  test_send_file_contents
  test_empty_context

  echo ""
  echo "========================================"
  echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
  [[ $TESTS_FAILED -gt 0 ]] && echo -e "${RED}$TESTS_FAILED failed${NC}"
  [[ $TESTS_FAILED -eq 0 ]] && echo -e "${GREEN}All passed!${NC}"

  if [[ "$WATCH_MODE" == "true" ]]; then
    echo ""
    echo "Attaching for inspection (Ctrl+B D to detach)..."
    trap - EXIT
    T attach-session -t "$SESSION_NAME"
    T kill-server 2>/dev/null || true
    rm -rf "$SCRATCHPAD"
  fi

  [[ $TESTS_FAILED -gt 0 ]] && exit 1
  exit 0
}

main
