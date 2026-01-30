# context-bridge.nvim

A Neovim plugin that seamlessly bridges code context from your editor to any AI agent running in a tmux pane.

## Features

- **Send & Submit** - Send code + questions and auto-submit to your AI agent
- **Stage Mode** - Build multi-part prompts by staging content without submitting
- **Plain Text** - Send arbitrary text without file/code context
- **Smart Pane Detection** - Automatically finds your agent in tmux (2-pane mode) or lets you select
- **Multiple Input Methods** - Visual selection, current line, file metadata, or entire file contents
- **Persistent Caching** - Remembers your agent pane across uses
- **Context-First Messaging** - Questions appear before code for better AI comprehension

## Quick Start

1. Select some code in Neovim
2. Press `,cc` (or your configured keymap)
3. Type your question about the code
4. Watch it auto-submit to your AI agent in tmux!

**Or build a multi-part prompt:**
1. `:ContextBridgeStageText` - "Here's what I'm working on:"
2. `,cc` on some code - Adds code context and submits

## Installation

### Manual Installation

1. Download `context-bridge.lua` to your Neovim lua directory:
   ```bash
   curl -o ~/.config/nvim/lua/context-bridge.lua \
     https://raw.githubusercontent.com/stevelounsbury/context-bridge/main/context-bridge.lua
   ```

2. Add to your `init.lua`:
   ```lua
   require('context-bridge').setup({
     keymaps = {
       visual_send = '<leader>cc',  -- Send visual selection
       line_send = '<leader>cl',    -- Send current line
       file_send = '<leader>cf',    -- Send file metadata
       text_send = '<leader>ct',    -- Send plain text
     }
   })
   ```

### Plugin Manager Installation

#### Packer
```lua
use {
  'stevelounsbury/context-bridge.nvim',
  config = function()
    require('context-bridge').setup()
  end
}
```

#### Lazy.nvim
```lua
{
  'stevelounsbury/context-bridge.nvim',
  config = function()
    require('context-bridge').setup()
  end
}
```

## Usage

### Keymaps (with default leader `,`)

**Send keymaps** (auto-submit):
| Keymap | Action |
|--------|--------|
| `,cc` | Send visual selection to agent |
| `,cl` | Send current line to agent |
| `,cf` | Send file metadata (name, type, lines, size) |
| `,ct` | Send plain text (no file context) |

**Stage keymaps** (no submit - for multi-part prompts):
| Keymap | Action |
|--------|--------|
| `,sc` | Stage visual selection |
| `,sl` | Stage current line |
| `,sb` | Stage file metadata |
| `,st` | Stage plain text |

### Commands

**Send commands** (submit automatically):
| Command | Action |
|---------|--------|
| `:ContextBridgeSend` | Send visual selection or range |
| `:ContextBridgeSendLine` | Send current line |
| `:ContextBridgeSendFile` | Send file metadata |
| `:ContextBridgeSendFileContents` | Send entire file contents |
| `:ContextBridgeSendText` | Send plain text |

**Stage commands** (send without submitting - for multi-part prompts):
| Command | Action |
|---------|--------|
| `:ContextBridgeStage` | Stage visual selection or range |
| `:ContextBridgeStageLine` | Stage current line |
| `:ContextBridgeStageFile` | Stage file metadata |
| `:ContextBridgeStageFileContents` | Stage entire file contents |
| `:ContextBridgeStageText` | Stage plain text |

**Pane management**:
| Command | Action |
|---------|--------|
| `:ContextBridgeSelectPane` | Manually select agent pane |
| `:ContextBridgeSetPane <id>` | Set pane ID directly |
| `:ContextBridgeClearCache` | Clear cached pane selection |

### Cancellation

Press `Ctrl+C` during the context/question prompt to cancel.

## Message Format

The plugin sends well-formatted messages with your question first:

```
What does this function do?

In file example.lua (lines 15-23):

```lua
local function process_data(input)
  if not input then return nil end
  return input:gsub("%s+", " "):trim()
end
```
```

File metadata format (`,cf`):
```
Tell me about this file

File: example.lua
- Type: lua
- Lines: 156
- Size: 4.2KB
```

## Configuration

```lua
require('context-bridge').setup({
  tmux_pane = 'agent',           -- Default pane name hint
  prompt_prefix = 'In file',     -- Prefix for file info
  auto_submit = true,            -- Auto-submit after send (false = stage by default)
  keymaps = {
    -- Send keymaps (auto-submit)
    visual_send = '<leader>cc',
    line_send = '<leader>cl',
    file_send = '<leader>cf',
    text_send = '<leader>ct',
    -- Stage keymaps (no submit) - set to false to disable
    visual_stage = '<leader>sc',
    line_stage = '<leader>sl',
    file_stage = '<leader>sb',
    text_stage = '<leader>st',
  }
})
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `tmux_pane` | `'agent'` | Hint for pane identification |
| `prompt_prefix` | `'In file'` | Prefix shown before filename |
| `auto_submit` | `true` | Whether to send Enter after message |
| `keymaps.visual_send` | `'<leader>cc'` | Send visual selection |
| `keymaps.line_send` | `'<leader>cl'` | Send current line |
| `keymaps.file_send` | `'<leader>cf'` | Send file metadata |
| `keymaps.text_send` | `'<leader>ct'` | Send plain text |
| `keymaps.visual_stage` | `'<leader>sc'` | Stage visual selection (no submit) |
| `keymaps.line_stage` | `'<leader>sl'` | Stage current line (no submit) |
| `keymaps.file_stage` | `'<leader>sb'` | Stage file metadata (no submit) |
| `keymaps.text_stage` | `'<leader>st'` | Stage plain text (no submit) |

## How It Works

### Pane Detection
1. **Two-pane auto-mode**: If you have exactly 2 tmux panes, it assumes the other one is your agent
2. **Interactive selection**: With 3+ panes, it shows pane numbers and lets you choose
3. **Persistent caching**: Remembers your choice until you clear it or restart Neovim

### Requirements
- Neovim with Lua support
- tmux
- Any terminal-based AI agent (Claude Code, ChatGPT CLI, etc.)

## Compatible AI Agents

This plugin works with any terminal-based AI tool:
- Claude Code
- ChatGPT CLI tools
- GitHub Copilot CLI
- Aider
- Custom AI scripts
- Any interactive terminal application

## Development

### Running Tests

The plugin includes integration tests that run in an isolated tmux environment:

```bash
./test/integration_test.sh           # Run all tests
./test/integration_test.sh --watch   # Wait before tests, attach after
./test/integration_test.sh --attach  # Manual testing mode
./test/integration_test.sh --debug   # Verbose output
```

## Contributing

Contributions welcome! Please feel free to submit issues and pull requests.

## License

MIT License - see LICENSE file for details.

## Author

Steve Lounsbury ([@stevelounsbury](https://github.com/stevelounsbury))

---

*Born from a need to seamlessly share code context with AI agents without the copy-paste dance!*
