# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ProGen CLI is the **command-line interface** package for [ProGen](https://github.com/andyl/pro_gen). It ships as a Mix archive (`mix archive.install github andyl/pro_gen_cli`) and provides `mix progen.*` tasks for running actions, validations, and commands from the terminal.

This is the **thin archive** — it contains only Mix tasks, shared CLI helpers, and the bootstrap/installer modules. All action and validation modules live in the core `pro_gen` package, which is fetched by `mix progen.install` into `~/.config/pro_gen/deps/`.

## Git Workflow

Do NOT automatically commit changes in this repo. Leave changes unstaged for manual review before committing.

## Build & Development Commands

```bash
mix compile          # Compile the project
mix test             # Run all tests (ExUnit)
mix test test/file.exs          # Run a single test file
mix test test/file.exs:LINE     # Run a specific test by line number
mix format           # Format code
mix format --check-formatted    # Check formatting
mix deps.get         # Fetch dependencies
mix archive.build    # Build the .ez archive
```

## Architecture

### Relationship to `pro_gen`

| Package | Repo | Contains | Ships as |
|---|---|---|---|
| `pro_gen` | `andyl/pro_gen` | Action/Validate behaviours, registries, built-in actions/validations, Script, Config | Hex package or GitHub dep |
| `pro_gen_cli` | `andyl/pro_gen_cli` | Mix tasks, CLI helpers, Bootstrap, GlobalConfig, Installer | Mix archive |

The dependency direction is one-way: `pro_gen_cli` depends on `pro_gen`, never the reverse. For local development, `mix.exs` uses `path: "../pro_gen"` when the sibling directory exists.

### Modules

**`ProGen.CLI`** — Shared helpers for Mix tasks: name resolution (`resolve_name/1`), argument parsing (`parse_kv_args/1`, `parse_checks/1`), output formatting (`format_table/1`, `format_list_json/1`, `format_list_text/1`), and source path lookup (`source_path/1`).

**`ProGen.CLI.GlobalConfig`** — Reads `~/.config/pro_gen/config.yml` (or `.yaml`). Public functions: `config_dir/0`, `deps_dir/0`, `config_path/0`, `read/0` (parses YAML, returns `{:ok, %{libs: list}}` or `{:error, msg}`), `validate/1` (validates lib entries, returns `{:ok, libs}` with normalized source tuples or `{:error, msg}`). Each lib is `%{name: string, source: {:path, p} | {:github, repo} | {:hex, pkg, vsn}}`. Config dir is overridable via `Application.put_env(:pro_gen_cli, :config_dir, path)` for testing.

**`ProGen.CLI.Bootstrap`** — Loads ProGen modules from `~/.config/pro_gen/deps/` at runtime. `ensure_loaded!/0` checks if `ProGen.Actions` is available; if not, calls `load_deps/0` to prepend `deps/*/ebin` to the code path. Raises with install instructions if modules still aren't found. Every Mix task calls `ensure_loaded!/0` first. When running inside a Mix project that depends on `pro_gen`, this is a no-op.

**`ProGen.CLI.Installer`** — Orchestrates `mix progen.install`. `install(libs, opts)` creates a temporary Mix project with all configured deps, runs `mix deps.get && mix deps.compile`, then copies or symlinks ebin dirs into `~/.config/pro_gen/deps/`. For `path:` deps, creates symlinks to the source project's `_build/dev/lib/<name>/ebin` so recompiling the source immediately reflects globally. Supports `force: true` to re-install. Returns `{:ok, summary}` or `{:error, summary}` with `%{installed: [], skipped: [], failed: []}`. If a lib named `"pro_gen"` has a `path:` source, it replaces the default github reference.

**Mix Tasks (13):** All tasks (except `install`) call `ProGen.CLI.Bootstrap.ensure_loaded!/0` as their first step.
- `mix progen.install [--force]` — Install ProGen and configured libraries globally
- `mix progen.action.list` — List all registered actions (table/text/json)
- `mix progen.action.info <name>` — Show action details
- `mix progen.action.run <desc> <name> [args]` — Execute an action
- `mix progen.action.cat <name>` — Display action source code
- `mix progen.action.edit <name>` — Open action source in `$EDITOR` (path deps only)
- `mix progen.validate.list` — List all validators
- `mix progen.validate.info <name>` — Show validator details
- `mix progen.validate.run <name> <checks>` — Execute validation checks
- `mix progen.validate.cat <name>` — Display validator source
- `mix progen.validate.edit <name>` — Open validator source in `$EDITOR` (path deps only)
- `mix progen.command.run <desc> <command>` — Execute a shell command
- `mix progen.puts <message>` — Print a formatted message

### Namespace Conventions

Both packages define modules in the `ProGen` namespace:
- `pro_gen` owns `ProGen.*` excluding `ProGen.CLI.*`
- `pro_gen_cli` owns `ProGen.CLI.*` and `Mix.Tasks.Progen.*`

## Dependencies

- **pro_gen** — Core library (path dep for local dev, github for CI)
- **yaml_elixir** — YAML config parsing for global config
