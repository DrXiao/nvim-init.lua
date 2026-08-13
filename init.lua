vim.cmd [[packadd packer.nvim]]

-- == Plugins ==================================================================

require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'

  use {
    'nvim-tree/nvim-tree.lua',
    tag      = 'compat-nvim-0.9',
    requires = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      -- herdr (terminal workspace manager) sets HERDR_ENV=1 in its panes.
      -- Its sidebar occupies the left side of the screen; the terminal sits
      -- to the right. We query herdr's layout API to get exact dimensions and
      -- adjust nvim-tree so the editor always occupies 65% of the full screen.
      --
      -- Layout: |<-- herdr H -->|<-- nvim-tree N -->|<-- editor E -->|
      --         |<-------------- full screen S = H + T ------------->|
      --         |<--------- terminal T (vim.o.columns) ------------->|
      --
      -- Goal: E = 0.65 * S  ->  N = T - 0.65 * S

      local MIN_TREE_WIDTH = 10
      local _herdr_H = nil  -- cached herdr sidebar width (columns)

      local function is_in_herdr()
        return os.getenv("HERDR_ENV") == "1"
      end

      -- Query herdr API for the sidebar width (area.x) of the current workspace.
      -- Returns nil on any error so callers can fall back gracefully.
      local function fetch_herdr_sidebar_width()
        local out = vim.fn.system("herdr api snapshot 2>/dev/null")
        if vim.v.shell_error ~= 0 then return nil end
        local ok, data = pcall(vim.json.decode, out)
        if not ok or type(data) ~= "table" then return nil end
        local layouts = vim.tbl_get(data, "result", "snapshot", "layouts")
        if not layouts then return nil end
        local ws = os.getenv("HERDR_WORKSPACE_ID")
        for _, layout in ipairs(layouts) do
          if layout.workspace_id == ws and layout.area then
            return layout.area.x
          end
        end
        if layouts[1] and layouts[1].area then  -- fallback: first layout
          return layouts[1].area.x
        end
        return nil
      end

      -- Width is evaluated lazily (as a function) so nvim-tree calls it at
      -- open time, after vim is fully initialised and herdr API is available.
      local function get_tree_width()
        local T = vim.o.columns
        if not is_in_herdr() then
          return math.floor(T * 0.35)
        end
        if _herdr_H == nil then
          _herdr_H = fetch_herdr_sidebar_width() or 0
        end
        local H = _herdr_H
        if H <= 0 then
          return math.floor(T * 0.35)
        end
        local S = T + H
        local tree_width = math.floor(T - 0.65 * S)
        return math.max(MIN_TREE_WIDTH, math.min(tree_width, math.floor(T * 0.5)))
      end

      require('nvim-tree').setup {
        view = {
          width = function() return get_tree_width() end,
          side   = "left",
        },
        git = {
          enable = true,
          ignore = false,
        },
        update_focused_file = {
          enable      = true,
          update_root = true,
        },
        respect_buf_cwd  = true,
        sync_root_with_cwd = true,
      }

      -- Auto-open on startup; skip when herdr mode yields a too-narrow tree.
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          if is_in_herdr() and get_tree_width() <= MIN_TREE_WIDTH then return end
          require("nvim-tree.api").tree.open()
        end,
      })

      -- Re-apply width on terminal resize; invalidate the cached sidebar width
      -- so the next get_tree_width() re-queries herdr if the layout changed.
      vim.api.nvim_create_autocmd("VimResized", {
        callback = function()
          _herdr_H = nil
          local view = require("nvim-tree.view")
          if view.is_visible() then
            view.close()
            if not (is_in_herdr() and get_tree_width() <= MIN_TREE_WIDTH) then
              require("nvim-tree.api").tree.open()
            end
          end
        end,
      })
    end,
  }

  use 'nvim-tree/nvim-web-devicons'
end)

-- == Options ==================================================================

vim.g.loaded_netrw       = 1
vim.g.loaded_netrwPlugin = 1

vim.o.number = true

vim.opt.exrc   = true
vim.opt.secure = true

-- == Global config ============================================================

-- Set indentation for JSON, YAML, and TOML files to 2 spaces.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "json", "jsonc", "yaml", "toml" },
  callback = function()
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
  end,
})

-- == Keymaps ==================================================================

local map = function(mode, lhs, rhs, opts)
  vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { noremap = true, silent = true }, opts or {}))
end

map('n', '<F2>', function() vim.cmd('tabnew'); require('nvim-tree.api').tree.open() end)
map('n', '<F3>', ':tabprevious<CR>')
map('n', '<F4>', ':tabnext<CR>')
map('n', '<F5>', ':NvimTreeToggle<CR>')
map('n', '<F6>', function() vim.o.number = not vim.o.number end)
map('n', '<F7>', ':tabclose<CR>')

-- == Local project config =====================================================

-- Walk up from cwd and source the first .nvim.lua found.
local function load_parent_nvimrc()
  local dir = vim.fn.getcwd()
  while dir ~= "/" do
    local candidate = dir .. "/.nvim.lua"
    if vim.fn.filereadable(candidate) == 1 then
      dofile(candidate)
      return
    end
    dir = vim.fn.fnamemodify(dir, ":h")
  end
end

load_parent_nvimrc()
