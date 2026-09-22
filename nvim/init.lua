vim.opt.number = true           -- Show absolute line number on the current line
vim.opt.termguicolors = true    -- Enable 24-bit RGB colors for modern themes
vim.opt.cursorline = true       -- Highlight the text line where the cursor is
vim.opt.clipboard = "unnamedplus" -- Sync Neovim clipboard with system clipboard
vim.opt.list = true -- Turn on the display of invisible characters
-- Define exactly which symbols to use for different whitespaces
vim.opt.listchars = {
    tab = '» ',      -- Show tabs as » followed by spaces
    trail = '·',     -- Show trailing spaces at the end of a line as dots
    nbsp = '␣',      -- Show non-breaking spaces
    extends = '›',   -- Show when a line continues off-screen to the right
    precedes = '‹',  -- Show when a line continues off-screen to the left
    space = '·',  -- OPTIONAL: Uncomment if you want EVERY single space to be a dot
}
