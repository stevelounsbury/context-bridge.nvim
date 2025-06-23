# context-bridge.nvim

A Neovim plugin that seamlessly bridges code context from your editor to any AI agent running in a tmux pane.

## Features

- 🚀 **Auto-submission** - Send code + questions and auto-submit to your AI agent
- 🎯 **Smart pane detection** - Automatically finds your agent in tmux (2-pane mode) or lets you select
- 📝 **Multiple input methods** - Visual selection, current line, or entire file
- 🔄 **Persistent caching** - Remembers your agent pane across uses
- 🌟 **Context-first messaging** - Questions appear before code for better AI comprehension

## Quick Demo

1. Select some code in Neovim
2. Press `,cc` (or your configured keymap)
3. Type your question about the code
4. Watch it auto-submit to your AI agent in tmux!

## Installation

### Manual Installation

1. Download `context-bridge.lua` to your Neovim lua directory:
   ```bash
   curl -o ~/.config/nvim/lua/context-bridge.lua https://raw.githubusercontent.com/stevelounsbury/context-bridge/main/context-bridge.lua
   ```

2. Add to your `init.lua`:
   ```lua
   require('context-bridge').setup({
     tmux_pane = 'agent',     -- Default pane identifier
     prompt_prefix = 'In file',
     keymaps = {
       visual_send = '<leader>cc',  -- Send visual selection
       line_send = '<leader>cl',    -- Send current line  
       file_send = '<leader>cf',    -- Send entire file
     }
   })
   ```

### Plugin Manager Installation

#### Packer
```lua
use {
  'stevelounsbury/context-bridge.nvim',
  config = function()
    require('context-bridge').setup({
      -- your config here
    })
  end
}
```

#### Lazy.nvim
```lua
{
  'stevelounsbury/context-bridge.nvim',
  config = function()
    require('context-bridge').setup({
      -- your config here  
    })
  end
}
```

## Usage

### Keymaps (with default leader `,`)
- `,cc` - Send visual selection to agent
- `,cl` - Send current line to agent  
- `,cf` - Send entire file to agent

### Commands
- `:ContextBridgeSend` - Send visual selection or range
- `:ContextBridgeSendLine` - Send current line
- `:ContextBridgeSendFile` - Send entire file
- `:ContextBridgeSelectPane` - Manually select agent pane
- `:ContextBridgeClearCache` - Clear cached pane selection

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

## How It Works

### Pane Detection
1. **Two-pane auto-mode**: If you have exactly 2 tmux panes, it assumes the other one is your agent
2. **Interactive selection**: With 3+ panes, it shows pane numbers and lets you choose
3. **Persistent caching**: Remembers your choice until you clear it or restart Neovim

### Requirements
- Neovim with Lua support
- tmux
- Any terminal-based AI agent (Claude Code, ChatGPT CLI, etc.)

## Configuration

```lua
require('context-bridge').setup({
  tmux_pane = 'agent',           -- Default pane name hint
  prompt_prefix = 'In file',     -- Prefix for file info
  keymaps = {
    visual_send = '<leader>cc',  -- Visual selection keymap
    line_send = '<leader>cl',    -- Current line keymap
    file_send = '<leader>cf',    -- Entire file keymap
  }
})
```

## Compatible AI Agents

This plugin works with any terminal-based AI tool:
- Claude Code
- ChatGPT CLI tools
- GitHub Copilot CLI
- Custom AI scripts
- Any interactive terminal application

## Contributing

Contributions welcome! Please feel free to submit issues and pull requests.

## License

MIT License - see LICENSE file for details.

## Author

Steve Lounsbury ([@stevelounsbury](https://github.com/stevelounsbury))

---

*Born from a need to seamlessly share code context with AI agents without the copy-paste dance!*