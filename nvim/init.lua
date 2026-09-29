-- ============================================================================
--  init.lua  —  Neovim 0.12+ single-file config
--  Stacks: Java/Spring Boot, Angular (TS/HTML/SCSS), Bash, Python
--  Plugin manager: built-in vim.pack   |   LSP: native vim.lsp.config/enable
-- ============================================================================

-- Leader keys must be set before plugins/keymaps are defined.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Faster startup: enable the Lua module bytecode cache.
vim.loader.enable()

-- ----------------------------------------------------------------------------
-- Options
-- ----------------------------------------------------------------------------
local o = vim.o

o.number = true          -- absolute line numbers
o.relativenumber = true  -- relative numbers for fast j/k motions (remove if unwanted)
o.cursorline = true      -- highlight the current line
o.termguicolors = true   -- 24-bit color (auto-detected since 0.10; explicit = safe)
o.clipboard = "unnamedplus" -- use the system clipboard for all yank/paste

o.winborder = "rounded"  -- default rounded border for ALL floating windows (0.11+)

o.signcolumn = "yes"     -- always show sign column (no text shifting)
o.mouse = "a"            -- mouse support
o.undofile = true        -- persistent undo across sessions
o.ignorecase = true      -- case-insensitive search...
o.smartcase = true       -- ...unless the query contains a capital
o.splitright = true      -- vertical splits open to the right
o.splitbelow = true      -- horizontal splits open below
o.scrolloff = 8          -- keep context lines around the cursor
o.expandtab = true       -- spaces instead of tabs
o.shiftwidth = 4         -- 4-space indents (overridden per-filetype below)
o.tabstop = 4
o.confirm = true         -- ask to save instead of failing on :q with changes

-- Whitespace visualization (your settings, preserved).
o.list = true
vim.opt.listchars = {
  tab = "» ",
  trail = "·",
  nbsp = "␣",
  extends = "›",
  precedes = "‹",
  space = "·",
}

-- Web/2-space languages: override indent width via an autocmd.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "typescript", "javascript", "html", "scss", "css", "json", "yaml", "lua", "sh", "bash" },
  callback = function() vim.bo.shiftwidth = 2; vim.bo.tabstop = 2 end,
})

-- ----------------------------------------------------------------------------
-- Diagnostics UI
-- ----------------------------------------------------------------------------
vim.diagnostic.config({
  severity_sort = true,
  update_in_insert = false,
  virtual_text = { spacing = 2, prefix = "●" },
  -- Toggle rich inline diagnostics with <leader>dl (see keymaps).
  float = { border = "rounded", source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN]  = "",
      [vim.diagnostic.severity.INFO]  = "",
      [vim.diagnostic.severity.HINT]  = "",
    },
  },
})

-- ----------------------------------------------------------------------------
-- Plugins (the whole list in one place — this is your blueprint)
-- ----------------------------------------------------------------------------
vim.pack.add({
  -- Theme + UI
  { src = "https://github.com/folke/tokyonight.nvim" },
  { src = "https://github.com/nvim-lualine/lualine.nvim" },
  { src = "https://github.com/nvim-mini/mini.icons" },

  -- Editing + navigation
  { src = "https://github.com/nvim-mini/mini.nvim" },      -- pairs, surround, ai
  { src = "https://github.com/stevearc/oil.nvim" },
  { src = "https://github.com/ibhagwan/fzf-lua" },
  { src = "https://github.com/folke/which-key.nvim" },
  { src = "https://github.com/lewis6991/gitsigns.nvim" },

  -- Treesitter (MAIN branch — full rewrite for 0.12)
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },

  -- LSP + tooling
  { src = "https://github.com/neovim/nvim-lspconfig" },     -- data-only lsp/*.lua configs
  { src = "https://github.com/mason-org/mason.nvim" },
  { src = "https://github.com/mason-org/mason-lspconfig.nvim" },
  { src = "https://github.com/stevearc/conform.nvim" },

  -- Completion (pin to 1.x: V2 has breaking changes; 1.x ships prebuilt binaries)
  { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1") },
  { src = "https://github.com/rafamadriz/friendly-snippets" },
})

-- ----------------------------------------------------------------------------
-- Theme
-- ----------------------------------------------------------------------------
require("tokyonight").setup({ style = "night" })
vim.cmd.colorscheme("tokyonight")

-- ----------------------------------------------------------------------------
-- Icons + statusline + editing modules
-- ----------------------------------------------------------------------------
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()  -- let lualine/fzf-lua/oil use mini.icons

require("mini.pairs").setup()    -- auto-close brackets/quotes
require("mini.surround").setup() -- add/change/delete surroundings (sa, sd, sr)
require("mini.ai").setup()       -- smarter a/i text objects (function, arg, etc.)

require("lualine").setup({
  options = { theme = "tokyonight", globalstatus = true, section_separators = "", component_separators = "" },
})

-- ----------------------------------------------------------------------------
-- File explorer (oil)
-- ----------------------------------------------------------------------------
require("oil").setup({ view_options = { show_hidden = true } })
vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory (oil)" })

-- ----------------------------------------------------------------------------
-- Git signs
-- ----------------------------------------------------------------------------
require("gitsigns").setup({
  on_attach = function(buf)
    local gs = require("gitsigns")
    local function map(m, l, r, d) vim.keymap.set(m, l, r, { buffer = buf, desc = d }) end
    map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
    map("n", "[h", function() gs.nav_hunk("prev") end, "Prev hunk")
    map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
    map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
    map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
    map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
  end,
})

-- ----------------------------------------------------------------------------
-- Fuzzy finder (fzf-lua)
-- ----------------------------------------------------------------------------
local fzf = require("fzf-lua")
fzf.setup({ "default" })
vim.keymap.set("n", "<leader>ff", fzf.files, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "Buffers" })
vim.keymap.set("n", "<leader>fh", fzf.helptags, { desc = "Help tags" })
vim.keymap.set("n", "<leader>fd", fzf.diagnostics_document, { desc = "Document diagnostics" })
vim.keymap.set("n", "<leader>fr", fzf.resume, { desc = "Resume last picker" })

-- ----------------------------------------------------------------------------
-- Treesitter (main branch API)
-- ----------------------------------------------------------------------------
local ensure_ts = {
  "bash", "c", "css", "scss", "html", "java", "javascript", "typescript", "tsx",
  "json", "lua", "luadoc", "markdown", "markdown_inline", "python", "query",
  "regex", "vim", "vimdoc", "yaml", "xml", "angular",
}
local ts_ok, ts = pcall(require, "nvim-treesitter")
if ts_ok then
  local installed = require("nvim-treesitter.config").get_installed()
  local to_install = vim.tbl_filter(function(p) return not vim.tbl_contains(installed, p) end, ensure_ts)
  if #to_install > 0 then ts.install(to_install) end
end

-- Enable highlighting + indentation per buffer.
vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev)
    pcall(vim.treesitter.start)
    vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})

-- Angular templates use the `angular` parser.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  pattern = { "*.component.html", "*.container.html" },
  callback = function() pcall(vim.treesitter.start, nil, "angular") end,
})

-- Recompile parsers whenever treesitter is updated by vim.pack.
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    if ev.data and ev.data.spec and ev.data.spec.name == "nvim-treesitter" and ev.data.kind == "update" then
      pcall(function() require("nvim-treesitter").update() end)
    end
  end,
})

-- ----------------------------------------------------------------------------
-- Completion (blink.cmp)
-- ----------------------------------------------------------------------------
require("blink.cmp").setup({
  keymap = { preset = "default" }, -- <C-y> accept,  <C-space> open, <C-n>/<C-p> select
  appearance = { nerd_font_variant = "mono" },
  sources = { default = { "lsp", "path", "snippets", "buffer" } },
  completion = {
    documentation = { auto_show = true, auto_show_delay_ms = 200 },
    menu = { draw = { treesitter = { "lsp" } } },
  },
  fuzzy = { implementation = "prefer_rust_with_warning" }, -- prebuilt binary, Lua fallback
})

-- ----------------------------------------------------------------------------
-- LSP
-- ----------------------------------------------------------------------------
-- Lombok for Spring Boot: the shipped lsp/jdtls.lua reads JDTLS_JVM_ARGS and
-- converts it into --jvm-arg=... so we don't have to override `cmd`.
vim.env.JDTLS_JVM_ARGS = "-javaagent:"
  .. vim.fn.expand("$HOME/.local/share/nvim/mason/packages/jdtls/lombok.jar")

require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = {
    "lua_ls",
    "jdtls",                    -- Java (needs JDK 21+ to run)
    "angularls", "vtsls",       -- Angular templates + TypeScript
    "cssls", "html",            -- SCSS/CSS + HTML
    "basedpyright", "ruff",     -- Python type-checking + lint/format
    "bashls",                   -- Bash (uses shellcheck)
  },
  -- automatic_enable = true is the default: installed servers are vim.lsp.enable()'d.
})

-- Global defaults: advertise blink.cmp completion capabilities to every server.
vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })

-- lua_ls: make editing this config pleasant.
vim.lsp.config("lua_ls", {
  settings = { Lua = {
    runtime = { version = "LuaJIT" },
    workspace = { checkThirdParty = false, library = vim.api.nvim_get_runtime_file("", true) },
    diagnostics = { globals = { "vim", "MiniIcons" } },
  } },
})

-- basedpyright: sensible defaults; let ruff own import organizing/formatting.
vim.lsp.config("basedpyright", {
  settings = { basedpyright = { analysis = { typeCheckingMode = "standard" } } },
})

-- Extra on-attach keymaps not provided by the 0.11 defaults.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local map = function(l, r, d) vim.keymap.set("n", l, r, { buffer = ev.buf, desc = d }) end
    map("gd", vim.lsp.buf.definition, "Go to definition")
    map("gD", vim.lsp.buf.declaration, "Go to declaration")
    -- grn/gra/grr/gri/grt/grx/gO/K are built-in defaults (Neovim 0.11+/0.12).
  end,
})

-- ----------------------------------------------------------------------------
-- Formatting (conform.nvim)
-- ----------------------------------------------------------------------------
require("conform").setup({
  formatters_by_ft = {
    java = { lsp_format = "prefer" },   -- jdtls formats Java
    typescript = { "prettierd", "prettier", stop_after_first = true },
    javascript = { "prettierd", "prettier", stop_after_first = true },
    html = { "prettierd", "prettier", stop_after_first = true },
    css = { "prettierd", "prettier", stop_after_first = true },
    scss = { "prettierd", "prettier", stop_after_first = true },
    json = { "prettierd", "prettier", stop_after_first = true },
    python = { "ruff_organize_imports", "ruff_format" },
    sh = { "shfmt" },
    bash = { "shfmt" },
    lua = { "stylua" },
  },
  default_format_opts = { lsp_format = "fallback" },
  format_on_save = { timeout_ms = 1000 },
})
vim.keymap.set({ "n", "v" }, "<leader>f", function()
  require("conform").format({ async = true })
end, { desc = "Format buffer/selection" })

-- ----------------------------------------------------------------------------
-- Misc keymaps
-- ----------------------------------------------------------------------------
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
vim.keymap.set("n", "<leader>dl", function()
  local cfg = vim.diagnostic.config()
  vim.diagnostic.config({ virtual_lines = not cfg.virtual_lines, virtual_text = cfg.virtual_lines })
end, { desc = "Toggle diagnostic virtual lines" })

require("which-key").setup()
