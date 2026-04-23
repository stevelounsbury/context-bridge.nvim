-- context-bridge.lua
-- Neovim plugin to send code selections with context to any agent in tmux

local M = {}

-- Default configuration
M.config = {
  tmux_pane = 'agent',
  prompt_prefix = 'In file',
  debug = false,
  keymaps = {
    visual_send = '<leader>cc',
    line_send = '<leader>cl',
    file_send = '<leader>cf',
  }
}

-- Cache for selected pane
M._cached_pane = nil

-- Setup function to override defaults
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
  M._setup_commands()
  M._setup_keymaps()
end

-- Check if a pane is still valid
local function is_pane_valid(pane_id)
  if not pane_id then return false end
  local cmd = 'tmux list-panes -F "#{pane_id}" 2>/dev/null | grep -q "' .. pane_id .. '"'
  local result = os.execute(cmd)
  return result == 0
end

-- Get the current pane ID
local function get_current_pane()
  local handle = io.popen('tmux display-message -p "#{pane_id}" 2>/dev/null')
  if handle then
    local result = handle:read("*a"):gsub("%s+", "")
    handle:close()
    return result
  end
  return nil
end

-- Find agent tmux pane
function M.get_agent_pane(force_reselect)
  -- Check if we're in tmux
  if not os.getenv("TMUX") then
    vim.notify("Not running in tmux session", vim.log.levels.WARN)
    return nil
  end
  
  -- Check cached pane if not forcing reselection
  if not force_reselect and M._cached_pane and is_pane_valid(M._cached_pane) then
    return M._cached_pane
  end
  
  -- First, check if we're in a 2-pane scenario
  local current_pane = get_current_pane()
  local cmd = 'tmux list-panes -F "#{pane_id}" 2>/dev/null'
  local handle = io.popen(cmd)
  if handle then
    local result = handle:read("*a")
    handle:close()
    
    local panes = {}
    for pane_id in result:gmatch("[^\r\n]+") do
      table.insert(panes, pane_id)
    end
    
    -- If there are exactly 2 panes, assume the other one is the agent
    if #panes == 2 then
      for _, pane_id in ipairs(panes) do
        if pane_id ~= current_pane then
          vim.notify("Found agent in 2-pane setup: " .. pane_id, vim.log.levels.INFO)
          M._cached_pane = pane_id
          return pane_id
        end
      end
    end
  end
  
  -- Otherwise, use interactive selection
  return M.select_pane_interactive()
end

-- Interactive pane selection using tmux display-panes
function M.select_pane_interactive()
  -- Show pane numbers
  os.execute('tmux display-panes')
  
  -- Get user input for which pane to use
  local pane_num = vim.fn.input('Select agent pane number: ')
  
  if pane_num == '' then
    vim.notify("No pane selected", vim.log.levels.WARN)
    return nil
  end
  
  -- Convert pane number to pane ID
  local cmd = 'tmux list-panes -F "#{pane_index} #{pane_id}"'
  local handle = io.popen(cmd)
  if handle then
    local result = handle:read("*a")
    handle:close()
    
    for line in result:gmatch("[^\r\n]+") do
      local index, pane_id = line:match("(%d+) (.+)")
      if index == pane_num then
        vim.notify("Selected pane: " .. pane_id, vim.log.levels.INFO)
        M._cached_pane = pane_id
        return pane_id
      end
    end
  end
  
  vim.notify("Invalid pane number: " .. pane_num, vim.log.levels.WARN)
  return nil
end

-- Clear cached pane selection
function M.clear_cache()
  M._cached_pane = nil
  vim.notify("Cleared cached pane selection", vim.log.levels.INFO)
end

-- No escaping needed when using send-keys -l
local function prepare_text_for_tmux(text)
  -- Just return the text as-is when using literal mode
  return text
end

-- Send text to agent
local function send_to_agent(text, context, start_line, end_line)
  local pane_id = M.get_agent_pane(false)
  if not pane_id then
    vim.notify("Error: Could not find agent tmux pane", vim.log.levels.ERROR)
    return false
  end
  
  local filename = vim.fn.expand('%:p')
  local relative_filename = vim.fn.expand('%')
  local filetype = vim.bo.filetype
  
  -- Build the message with question/context first
  local message = ''
  
  -- Put context/question at the top if provided
  if context and context ~= '' then
    message = context .. '\n\n'
  end
  
  -- Add file info
  message = message .. M.config.prompt_prefix .. ' ' .. relative_filename
  if start_line == end_line then
    message = message .. ' (line ' .. start_line .. '):'
  else
    message = message .. ' (lines ' .. start_line .. '-' .. end_line .. '):'
  end
  
  -- Add code block
  message = message .. '\n\n```' .. filetype .. '\n' .. text .. '\n```'
  
  -- Clear any existing input in agent
  os.execute('tmux send-keys -t ' .. pane_id .. ' C-c')
  vim.wait(200)
  
  -- Send the entire message as literal text (preserves newlines)
  -- Use single quotes and escape any single quotes in the message
  local escaped_message = message:gsub("'", "'\"'\"'")
  os.execute(string.format("tmux send-keys -t %s -l '%s'", pane_id, escaped_message))
  
  -- Small delay then send Enter to submit the complete prompt
  vim.wait(100)
  os.execute('tmux send-keys -t ' .. pane_id .. ' Enter')
  
  vim.notify('Sent selection to agent (pane ' .. pane_id .. ')', vim.log.levels.INFO)
  return true
end

-- Get visual selection
function M.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]
  
  local lines = vim.fn.getline(start_line, end_line)
  if #lines == 0 then
    return nil, start_line, end_line
  end
  
  -- Handle single line selection
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_col, end_col)
  else
    -- Handle multi-line selection
    lines[1] = string.sub(lines[1], start_col)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
  end
  
  return table.concat(lines, '\n'), start_line, end_line
end

-- Prompt for context with input
local function get_context_input()
  local context = vim.fn.input('Context/Question (optional): ')
  return context
end

-- Send visual selection
function M.send_visual()
  local text, start_line, end_line = M.get_visual_selection()
  if not text or text == '' then
    vim.notify('No text selected', vim.log.levels.WARN)
    return
  end
  
  local context = get_context_input()
  send_to_agent(text, context, start_line, end_line)
end

-- Send current line
function M.send_line()
  local current_line = vim.fn.line('.')
  local text = vim.fn.getline(current_line)
  
  if not text or text == '' then
    vim.notify('Current line is empty', vim.log.levels.WARN)
    return
  end
  
  local context = get_context_input()
  send_to_agent(text, context, current_line, current_line)
end

-- Send entire file
function M.send_file()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, '\n')
  local total_lines = vim.fn.line('$')
  
  local context = get_context_input()
  send_to_agent(text, context, 1, total_lines)
end

-- Send a specific range
function M.send_range(start_line, end_line)
  local lines = vim.fn.getline(start_line, end_line)
  local text = table.concat(lines, '\n')
  
  local context = get_context_input()
  send_to_agent(text, context, start_line, end_line)
end

-- Setup commands
function M._setup_commands()
  vim.api.nvim_create_user_command('ContextBridgeSend', function(opts)
    if opts.range == 2 then
      M.send_range(opts.line1, opts.line2)
    else
      M.send_visual()
    end
  end, { range = true })
  
  vim.api.nvim_create_user_command('ContextBridgeSendLine', M.send_line, {})
  vim.api.nvim_create_user_command('ContextBridgeSendFile', M.send_file, {})
  vim.api.nvim_create_user_command('ContextBridgeSelectPane', function()
    M.get_agent_pane(true)
  end, {})
  vim.api.nvim_create_user_command('ContextBridgeClearCache', M.clear_cache, {})
end

-- Setup keymaps
function M._setup_keymaps()
  local keymaps = M.config.keymaps
  
  if keymaps.visual_send then
    vim.keymap.set('v', keymaps.visual_send, function()
      -- Exit visual mode first to set the '< and '> marks
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
      vim.schedule(function()
        M.send_visual()
      end)
    end, { desc = 'Send visual selection to agent' })
  end
  
  if keymaps.line_send then
    vim.keymap.set('n', keymaps.line_send, function()
      M.send_line()
    end, { desc = 'Send current line to agent' })
  end
  
  if keymaps.file_send then
    vim.keymap.set('n', keymaps.file_send, function()
      M.send_file()
    end, { desc = 'Send entire file to agent' })
  end
end

-- Auto-setup with defaults if not already configured
if not M._setup_done then
  M.setup({})
  M._setup_done = true
end

return M
