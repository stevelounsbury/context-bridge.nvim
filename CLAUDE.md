# Context Bridge - Neovim Plugin for AI Agent Integration

## Project Overview

Context Bridge is a Neovim plugin that enables seamless integration with any AI agent or tool running in a tmux pane. Originally built for Claude Code, it has been generalized to work with any terminal-based AI assistant. The plugin allows developers to send code selections directly from Neovim with context and questions, automatically handling the submission.

## Plugin Details

- **Name:** context-bridge.nvim
- **Author:** Steve Lounsbury (@stevelounsbury)
- **File:** `~/.config/nvim/lua/context-bridge.lua`
- **Purpose:** Bridge code context from Neovim to any AI agent in tmux

## Workflow

1. **User selects code** in Neovim (visual selection, current line, or entire file)
2. **Plugin prompts** for optional context/questions about the selected code
3. **Plugin automatically finds** the tmux pane running the AI agent
4. **Plugin sends** formatted message with question first, then file info, line numbers, and code block
5. **Plugin auto-submits** the prompt (no manual intervention needed)

## Key Features

### Smart Pane Detection
- **Two-pane auto-detection** - If exactly 2 panes exist, assumes the other is the agent
- **Interactive selection** - Shows tmux pane numbers for manual selection when 3+ panes
- **Persistent caching** - Remembers selected pane across uses until cleared

### Auto-Submission
- **Input clearing** - Sends Ctrl+C to clear any existing input
- **Reliable text transfer** - Uses proper shell escaping with literal mode
- **Automatic submission** - Sends Enter key after message for hands-free operation

### Multiple Input Methods
- Visual selection with context (`<leader>cc`)
- Current line with context (`<leader>cl`)
- File reference/metadata (`<leader>cf`) - sends filename, type, line count, size
- Full file contents via `:ContextBridgeSendFileContents` command
- Custom line ranges via commands
- Proper file and line number reporting

## Installation & Configuration

**Current Setup in init.lua:**
```lua
-- Context Bridge plugin setup (local module)
require('context-bridge').setup({
  tmux_pane = 'agent',
  prompt_prefix = 'In file',
  keymaps = {
    visual_send = '<leader>cc',
    line_send = '<leader>cl',
    file_send = '<leader>cf',
  }
})
```

## Usage

### Keymaps
- `,cc` - Send visual selection to agent
- `,cl` - Send current line to agent
- `,cf` - Send file reference (metadata only: name, type, lines, size)

### Commands
- `:ContextBridgeSend` - Send visual selection or range
- `:ContextBridgeSendLine` - Send current line
- `:ContextBridgeSendFile` - Send file reference (metadata only)
- `:ContextBridgeSendFileContents` - Send entire file contents
- `:ContextBridgeSelectPane` - Force pane re-selection
- `:ContextBridgeSetPane <pane_id>` - Set target pane explicitly (useful for testing)
- `:ContextBridgeClearCache` - Clear cached pane selection

### Cancellation
Press `Ctrl+C` during the context/question prompt to cancel the operation.

### Direct Function Calls (for testing)
```vim
:lua require('context-bridge').send_line()
:lua require('context-bridge').send_visual()
:lua require('context-bridge').send_file()
:lua require('context-bridge').send_file_contents()
:lua require('context-bridge').get_agent_pane()
```

## Message Format

The plugin sends formatted messages with context/question first:

```
[Your question/context if provided]

In file [relative_filename] (lines X-Y):

```[filetype]
[selected code]
```
```

## Technical Implementation

### Pane Detection
1. **Cache check** - Validates cached pane is still active
2. **Two-pane mode** - Auto-selects the other pane when only 2 exist
3. **Interactive mode** - Uses `tmux display-panes` for manual selection
4. **Pane validation** - Ensures selected pane still exists before use

### Text Transmission
- **Shell escaping** - Properly escapes single quotes in content
- **Literal mode** - Uses `tmux send-keys -l` for reliable text transfer
- **Single submission** - Sends entire message at once, then Enter key

### Visual Selection Handling
- **Proper mark handling** - Exits visual mode to set '< and '> marks
- **Scheduled execution** - Ensures marks are set before reading selection
- **Column-aware** - Handles partial line selections correctly

## Development History

1. **Initial implementation** as claude-code.lua with smart detection features
2. **Simplified pane detection** to 2-pane auto mode + interactive selection
3. **Fixed auto-submission** issues with proper shell escaping
4. **Restructured message format** to put questions first
5. **Renamed to context-bridge** for generic AI agent support
6. **Cleaned up** all Claude-specific references
7. **Added Ctrl+C cancellation** - pressing Ctrl+C during context prompt cancels the operation
8. **Changed file send to metadata** - `send_file()` now sends reference info, added `send_file_contents()` for full contents
9. **Added integration tests** - automated tests using isolated tmux server (`test/integration_test.sh`)

## Current Status

✅ **Plugin fully functional and tested**
✅ **Simplified pane detection working reliably**
✅ **Auto-submission working with all content types**
✅ **Generic naming for any AI agent**
✅ **Integration tests passing** (`./test/integration_test.sh`)
✅ **Ready for public release**  

The plugin provides a smooth developer workflow where code can be sent with context to any AI assistant without leaving Neovim or requiring manual interaction in the agent's interface.