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

## Related

- [pro_gen](https://github.com/andyl/pro_gen) — Core library with action/validation behaviours, registries, and scripting support
