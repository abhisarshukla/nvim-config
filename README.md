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
| `lua/plugins/mason.lua` | Installs language servers and formatters |
| `lua/plugins/treesitter.lua` | Parsers, code text objects, sticky context line |
| `lua/plugins/lsp.lua` | Language servers, diagnostics, inlay hints |
| `lua/plugins/completion.lua` | blink.cmp + snippets |
| `lua/plugins/format.lua` | conform.nvim: format on save where the project opts in |
| `lua/plugins/snacks.lua` | Picker and word references |
| `lua/plugins/oil.lua` | Folders as editable buffers |
| `lua/rex/` | Run tasks/commands in a Rex pane, errors back to quickfix (`init` keys, `pane`, `run`, `tasks`) |
| `lua/statusline.lua` | Hand-written statusline |
| `after/ftplugin/` | Per-language settings (indent, wrapping) |
| `after/lsp/` | Per-server overrides on top of nvim-lspconfig |
| `snippets/` | Your own snippets (VS Code JSON format) |
| `nvim-pack-lock.json` | Exact plugin versions — commit it |

## Keys

Built-in keys still work; this lists what's added or changed.

**Files and search**

| Key | Action |
| --- | --- |
| `<leader>ff` / `fb` / `fr` | Find files / open buffers / recent files |
| `<leader>sg` / `sw` | Grep project / grep word or selection |
| `<leader>sd` / `sh` / `sk` | Search diagnostics / help / keymaps |
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

| Language | Server | Formatter (on save) |
| --- | --- | --- |
| Python | ty + ruff | ruff, if `ruff.toml` or `[tool.ruff]` exists |
| TypeScript / JS | vtsls | Biome or Prettier, if configured in the project |
| Go | gopls | goimports, always |
| Rust | rust-analyzer | rustfmt, always |
| Lua | lua_ls | stylua, if `stylua.toml` exists |

Tools come from mason (`:Mason`); add one to the list in
`lua/plugins/mason.lua`. Parsers are listed in `lua/plugins/treesitter.lua`.

System requirements: `git`, `tree-sitter` (brew `tree-sitter-cli`), `rg`, `fd`,
a C compiler, `go` and `cargo` (for gopls/rustfmt), and a Nerd Font.
