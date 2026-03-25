# ProGen CLI

Command-line interface for [ProGen](https://github.com/andyl/pro_gen), shipped
as a Mix archive. Provides `mix progen.*` tasks for running actions,
validations, and commands from the terminal.

## Installation

```bash
mix archive.install github andyl/pro_gen_cli
```

To update to the latest version:

```bash
mix archive.install github andyl/pro_gen_cli --force
```

To uninstall:

```bash
mix archive.uninstall pro_gen_cli
```

## Requirements

- Elixir ~> 1.19

## Usage

Once installed, the following Mix tasks are available globally:

### Actions

```bash
mix progen.action.list              # List all registered actions
mix progen.action.info <name>       # Show action details
mix progen.action.run <desc> <name> [args]  # Execute an action
mix progen.action.cat <name>        # Display action source code
```

### Validations

```bash
mix progen.validate.list            # List all validators
mix progen.validate.info <name>     # Show validator details
mix progen.validate.run <name> <checks>  # Execute validation checks
mix progen.validate.cat <name>      # Display validator source
```

### Utilities

```bash
mix progen.command.run <desc> <command>  # Execute a shell command
mix progen.puts <message>               # Print a formatted message
```

## Configuration

ProGen CLI reads an optional config file at `~/.config/pro_gen/config.yml` (or
`.yaml`) to declare third-party action/validation libraries. Running
`mix progen.install` fetches and compiles these libraries into
`~/.config/pro_gen/deps/`, making them available to all `mix progen.*` tasks.

### Config file format

```yaml
libs:
  - name: my_actions
    path: /home/user/src/my_actions

  - name: team_utils
    github: myorg/pro_gen_utils

  - name: community_pack
    hex: pro_gen_community
    version: "~> 0.2"
```

Each entry under `libs:` requires a `name` and exactly one source key:

| Source   | Keys                | Description                                                                 |
|----------|---------------------|-----------------------------------------------------------------------------|
| `path`   | `path:`             | Absolute path to a local project. Symlinked into deps so recompiles reflect immediately. |
| `github` | `github:`           | GitHub `owner/repo` reference. Fetched and compiled during install.         |
| `hex`    | `hex:` + `version:` | Hex package name with a version requirement (e.g. `"~> 0.2"`). Both fields are required. |

### Example: local development with `pro_gen` from source

To use a local checkout of `pro_gen` itself (useful when developing actions):

```yaml
libs:
  - name: pro_gen
    path: /home/user/src/pro_gen
```

When a lib named `pro_gen` has a `path:` source, the installer uses it in place
of the default GitHub reference.

### Notes

- If the config file is missing or empty, `mix progen.install` installs only
  the core `pro_gen` library from GitHub.
- Each lib entry must have **exactly one** source key — specifying more than one
  (e.g. both `path:` and `hex:`) is an error.
- Run `mix progen.install --force` to re-install all libraries.

## Related

- [pro_gen](https://github.com/andyl/pro_gen) — Core library with action/validation behaviours, registries, and scripting support
