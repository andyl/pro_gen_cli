# Feature Spec: Progen Help Task

**Date:** 2026-03-26
**Branch:** `feat/progen-help-task`
**Status:** Draft

## Summary

Add a `mix progen` task that dynamically assembles and prints a help overview
for the entire `progen` namespace, similar to how `mix hex` prints a summary of
all hex tasks.

## Motivation

As the number of `mix progen.*` tasks grows, users need a single entry point to
discover what's available. Running `mix progen` should print a formatted help
page showing every progen task grouped by namespace, with argument signatures
and short descriptions. This must be self-assembling via introspection so it
never goes stale when tasks are added or changed.

## Requirements

### Help Output

1. **`mix progen`** — Print a formatted help overview of all `progen.*` Mix
   tasks. No arguments required.

2. **Dynamic discovery** — The task must discover all loaded Mix tasks whose
   name starts with `progen.` at runtime using introspection (e.g.,
   `Mix.Task.load_all/0` and filtering). It must not use a hardcoded list.

3. **Grouped by namespace** — Tasks are grouped by their second segment (e.g.,
   `progen.action.*`, `progen.validate.*`, `progen.command.*`). Each group is
   separated by a visual divider line.

4. **Per-task display** — Each task entry shows:
   - The full task name (e.g., `mix progen.action.run`)
   - Argument signature (e.g., `"message" <action> [key=value ...]`)
   - A short one-line description

5. **Sorted output** — Tasks within each group are sorted alphabetically.
   Groups themselves are sorted alphabetically by namespace.

6. **Consistent formatting** — Output should be aligned in columns for
   readability, similar to the `mix hex` help output.

### Introspection Approach

7. **Use Mix task metadata** — Extract the short description from each task's
   `@shortdoc` attribute. Extract argument info from the task's `@moduledoc` or
   a dedicated function if available.

8. **Resilient to missing metadata** — If a task lacks `@shortdoc`, show the
   task name with no description rather than crashing or omitting it.

### Location

9. **Lives in pro_gen_cli** — This is a Mix task (`Mix.Tasks.Progen`) and
   belongs in the `pro_gen_cli` package, not in the core `pro_gen` library.

## Acceptance Criteria

- Running `mix progen` prints a formatted help page to stdout.
- All `progen.*` tasks that are currently loaded appear in the output.
- Tasks are grouped by namespace with divider lines between groups.
- Each task shows its name, args, and short description.
- Adding a new `mix progen.foo.bar` task with `@shortdoc` automatically appears
  in the help output without any changes to the help task.
- Removing a task automatically removes it from the help output.
- The output is well-aligned and readable in a standard 80-column terminal.
- All existing tests continue to pass.

## Out of Scope

- Color or ANSI formatting (can be added later).
- Filtering or searching tasks (e.g., `mix progen --search foo`).
- Verbose mode showing full `@moduledoc`.
- Interactive selection of tasks.
