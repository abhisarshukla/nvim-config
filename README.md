# Neovim config

Neovim 0.12, plugins managed by the built-in `vim.pack`. Built-ins first; a
plugin only where Neovim hits a real limit. Leader is `Space`.

## Layout

| File | What it does |
| --- | --- |
| `init.lua` | Loads everything below, in this order |
| `lua/options.lua` | Editor options |
| `lua/autocmds.lua` | Yank highlight; clipboard (yank → macOS clipboard, copied text → `p`) |
| `lua/keymaps.lua` | General mappings |
| `lua/pack.lua` | Plugin hooks, `:PackUpdate` / `:PackClean` / `:PackCheck`, daily update check |
| `lua/plugins/ui.lua` | tokyonight, mini.icons, mini.clue (key hints) |
| `lua/plugins/mason.lua` | mason (installs language servers and formatters on demand) |
| `lua/plugins/treesitter.lua` | Highlighting/folds on, code text objects, sticky context line |
| `lua/plugins/lsp.lua` | LSP keys, diagnostics, inlay hints |
| `lua/plugins/fidget.lua` | LSP progress in the corner |
| `lua/plugins/completion.lua` | blink.cmp + snippets |
| `lua/plugins/format.lua` | conform.nvim: when each formatter may run (project opt-in) |
| `lua/plugins/snacks.lua` | Picker, word references, statuscolumn |
| `lua/plugins/oil.lua` | Folders as editable buffers |
| `lua/plugins/git.lua` | gitsigns: change signs, hunks, blame, diffs |
| `lua/rex/` | Run tasks/commands in a Rex pane, errors back to quickfix (`init` keys, `pane`, `run`, `tasks`) |
| `lua/statusline.lua` | Hand-written statusline |
| `lua/keyhelp.lua` | Key lookup: searchable table of every key |
| `lua/ask.lua` | Ask Claude about Neovim, your config or keys |
| `lua/tools.lua` | Helpers for ftplugins: install missing mason tools / parsers once |
| `ftplugin/<ft>.lua` | Per-language setup: server, parser, tools, formatter (runs when that filetype opens) |
| `lua/lang/typescript.lua` | Setup shared by the four JS/TS filetypes |
| `after/ftplugin/<ft>.lua` | Per-language option overrides (indent, wrapping) |
| `after/lsp/` | Per-server overrides on top of nvim-lspconfig |
| `snippets/` | Your own snippets (VS Code JSON format) |
| `nvim-pack-lock.json` | Exact plugin versions — commit it |

## Keys

Built-in keys still work; this lists what's added or changed.

**Forgot a key?**

| Key | Action |
| --- | --- |
| `<leader>sk` | Table of every key — yours, plugins', Vim's built-ins. Search by key or description (`blame`, `center`, `split window`); preview shows where it's defined; `<CR>` runs it |
| `<leader>?` | Ask Claude anything about Neovim, your config, plugins or keys, in plain English. It reads Neovim 0.12's help, plugin docs and this config (read-only; Haiku via `claude -p`). In the answer: `a` follow-up, `r` run the suggested command, `q` close |
| pause after `<leader>`, `g`, `[`, `]`, `z`, `<C-w>` | Popup of what comes next |

**Files and search**

| Key | Action |
| --- | --- |
| `<leader>ff` / `fb` / `fr` | Find files / open buffers / recent files |
| `<leader>sg` / `sw` | Grep project / grep word or selection |
| `<leader>sd` / `sh` | Search diagnostics / help |
| `<leader>sr` | Resume last search |
| `-` | Open current file's folder in oil (edit, then `:w`) |

**Code**

| Key | Action |
| --- | --- |
| `gd` `grr` `gri` `grt` `gO` | Definition, references, implementations, type, symbols (picker) |
| `K`, `grn`, `gra`, `<C-s>` | Hover, rename, code action, signature (built-in) |
| `]r` / `[r` | Next / previous use of the symbol under the cursor |
| `af` `if` `ac` `ic` `aa` `ia` | Function / class / argument text objects |
| `]m` `[m` `]M` `[M` | Next / previous function start / end |
| `]]` `[[` | Next / previous class |
| `<leader>th` | Toggle inlay hints |
| `<C-y>` / `<C-Space>` / `<Tab>` | Accept completion / open menu / next snippet field |

**Git** (signs on the right of the line numbers: added / changed / deleted)

| Key | Action |
| --- | --- |
| `]h` / `[h`, `]H` / `[H` | Next / previous hunk, last / first hunk |
| `ih` | Hunk text object (`vih`, `dih`, ...) |
| `<leader>gp` / `gi` | Preview hunk in a popup / inline |
| `<leader>gd` / `gD` | Diff file against the index / the last commit |
| `<leader>gq` | All hunks in the repo → quickfix |
| `<leader>gb` / `gB` | Blame this line (full commit) / whole file |
| `<leader>tb` | Toggle blame at the end of the current line |
| `<leader>gs` / `gr` | Stage / reset hunk (or selected lines in visual) |
| `<leader>gS` / `gR` | Stage / reset the whole file |

**Rex** (only when nvim runs inside Rex)

Commands run in the pane labeled `run`; if there isn't one, it's created
below nvim. Errors land in the quickfix list (`]q` / `[q`), the full output in
a log buffer.

| Key | Action |
| --- | --- |
| `<leader>rt` / `rb` / `rl` | Run the project's test / build / lint task |
| `<leader>ra` | Pick a task (or edit this project's tasks) |
| `<leader>rr` | Re-run the last task or command (remembered per project) |
| `<leader>rc` | Run any command |
| `<leader>rh` | Pick from this project's history |
| `<leader>rx` | Interrupt (Ctrl-C) |
| `<leader>rw` | Toggle re-run on save (project files only; restarts a run in progress) |
| `<leader>rq` / `ro` | Reload results / open the output log |
| `<leader>rv` | Hide the pane in a background tab / bring it back |
| `<leader>rk` | Close the pane |
| `<leader>rp` | Use a different pane for this session |

Tasks: Rust, Go, Python and Node projects get built-in test/build/lint tasks.
`:RexTasks` opens this project's private task file (kept in nvim's data
folder, not the repo) to add tasks, change commands, or give tasks their own
`<leader>r` key.

## Plugins

- **Update:** you're told once a day if updates exist. `:PackUpdate` shows
  the changes; `:write` applies, `:quit` cancels. Commit the lockfile after.
- **Roll back:** `git checkout -- nvim-pack-lock.json`, `:restart`, then
  `:lua vim.pack.update(nil, { target = 'lockfile' })`.
- **Add:** create `lua/plugins/<name>.lua` with `vim.pack.add({...})` and
  setup, then add a `require` line to `init.lua`. Use
  `version = vim.version.range('X.*')` when the plugin publishes releases.
  Build steps go in the `hooks` table in `lua/pack.lua`.
- **Remove:** delete its file and `require`, `:restart`, then `:PackClean`.

## Languages

Each language is set up by Neovim's own ftplugin loading: opening a Rust file
sources `ftplugin/rust.lua`, which enables the server, installs the parser and
mason tools if missing (they switch on as soon as they're ready), and picks
the formatter. Option overrides go in `after/ftplugin/<ft>.lua`, server
settings in `after/lsp/<server>.lua`.

| Language | Server | Formatter (on save) |
| --- | --- | --- |
| Python | ty + ruff | ruff, if `ruff.toml` or `[tool.ruff]` exists |
| TypeScript / JS | vtsls | Biome or Prettier, if configured in the project |
| Go | gopls | goimports, always (tabs while typing) |
| Rust | rust-analyzer | rustfmt, always |
| Lua | lua_ls | stylua, if `stylua.toml` exists |
| JSON, CSS | — | Biome or Prettier, if configured |
| HTML, YAML, Markdown | — | Prettier, if configured |
| TOML, shell | — | — |

**Add a language:** create `ftplugin/<filetype>.lua` (`:set ft?` shows the
name) with any of:

```lua
vim.lsp.enable('server_name')                       -- name from nvim-lspconfig
require('tools').ensure({ 'mason-package' })       -- :Mason lists packages
require('tools').parsers({ 'parser' })
require('conform').formatters_by_ft.<ft> = { 'formatter' }
```

If a formatter should only run when the project opts in, add its condition in
`lua/plugins/format.lua`.

System requirements: `git`, `tree-sitter` (brew `tree-sitter-cli`), `rg`, `fd`,
a C compiler, `go` and `cargo` (for gopls/rustfmt), and a Nerd Font.
