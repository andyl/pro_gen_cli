# Implementation Plan: Progen Help Task

**Spec:** `_spec/features/260326_progen-help-task.md`
**Generated:** 2026-03-26

---

## Goal

Add a `mix progen` task that dynamically discovers all `progen.*` Mix tasks at runtime and prints a grouped, formatted help overview — so users have a single entry point for discovering available commands.

## Scope

### In scope
- New `Mix.Tasks.Progen` module at `lib/mix/tasks/progen.ex`
- Dynamic task discovery via `Mix.Task.load_all/0` + filtering
- Grouping by second namespace segment (action, validate, command, etc.)
- Per-task display: name, argument signature, short description
- Alphabetical sorting within and across groups
- Column-aligned output readable at 80 columns
- Graceful handling of tasks missing `@shortdoc`
- Tests for the new task

### Out of scope
- ANSI color formatting
- `--search` / filtering flags
- Verbose mode showing full `@moduledoc`
- Interactive task selection

## Architecture & Design Decisions

1. **Single file, no new helpers in `ProGen.CLI`** — The help task is self-contained. Formatting logic (grouping, alignment) lives in private functions within the task module. No need to add helpers to `ProGen.CLI` since this formatting is specific to the help output and won't be reused.

2. **`Mix.Task.load_all/0` for discovery** — This is the standard Mix introspection API. Filter results to modules whose task name starts with `"progen."`. This ensures new tasks appear automatically.

3. **Argument signatures from `@moduledoc`** — Extract the first code-fenced `mix progen.*` line from each task's `@moduledoc`. All existing tasks follow the pattern of having a `bash` code block with the usage line. If no signature is found, show just the task name with no args.

4. **No `Bootstrap.ensure_loaded!/0` call** — The help task only introspects Mix task modules that are already compiled and loaded. It doesn't need ProGen core modules, so it should skip the bootstrap step. This means `mix progen` works even before `mix progen.install` has been run.

5. **Group header format** — Use a simple header like `progen.action` followed by a divider line (`---`) before the task entries in that group. Standalone tasks (e.g., `progen.install`, `progen.puts`) with no sub-namespace go in a top-level group.

## Implementation Steps

1. **Create the Mix task module**
   - File: `lib/mix/tasks/progen.ex`
   - Define `Mix.Tasks.Progen` with `use Mix.Task`
   - Add `@shortdoc "Print help for all progen tasks"`
   - Implement `run/1` that:
     a. Calls `Mix.Task.load_all()` to ensure all tasks are loaded
     b. Filters to task names matching `~r/^progen\./`
     c. For each task, extracts: task name, `@shortdoc` (or `""`), and argument signature from `@moduledoc`
     d. Groups tasks by second segment (e.g., `"action"`, `"validate"`)
     e. Tasks with only one segment after `progen` (like `progen.install`) go in a `"progen"` top-level group
     f. Sorts groups alphabetically, sorts tasks within groups alphabetically
     g. Formats and prints output via `Mix.shell().info/1`

2. **Implement argument signature extraction**
   - File: `lib/mix/tasks/progen.ex` (private function)
   - Parse `@moduledoc` for the first line matching `mix progen.<name> ...` inside a code fence
   - Strip the `mix <task_name>` prefix, return remaining args (e.g., `"\"message\" <action> [key=value ...]"`)
   - Return `""` if no moduledoc or no matching line

3. **Implement output formatting**
   - File: `lib/mix/tasks/progen.ex` (private functions)
   - Calculate max task name width for column alignment
   - Format: `  mix progen.action.run  "message" <action> [key=value ...]  Run a ProGen action`
   - Three columns: task name (left-aligned, padded), args (padded), description
   - Group header: blank line + `=== progen.action ===` or similar visual separator
   - Include a header line like `"ProGen — available tasks:\n"`

4. **Write tests**
   - File: `test/pro_gen/cli/help_task_test.exs`
   - Test that `Mix.Tasks.Progen.run([])` produces output containing:
     - Known task names (e.g., `progen.action.list`, `progen.install`)
     - Group headers for `action`, `validate`, `command`
     - Short descriptions from `@shortdoc`
   - Test that output includes the help task itself (`progen`)
   - Test that tasks are sorted alphabetically within groups
   - Test resilience: a task without `@shortdoc` still appears (harder to test without a fixture, but can verify no crash)

5. **Verify all existing tests pass**
   - Run `mix test` to confirm no regressions

## Dependencies & Ordering

- Step 1 must be completed before Step 4 (tests need the module to exist)
- Steps 1–3 are all within the same file and should be done together
- Step 5 runs after Steps 1–4

## Edge Cases & Risks

- **Tasks without `@shortdoc`**: Show the task name with an empty description. The `Mix.Task.shortdoc/1` function returns `nil` for these — handle with `|| ""`.
- **Tasks without `@moduledoc`**: Show no argument signature. The `Module.get_attribute/2` or `Code.fetch_docs/1` approach must handle `nil` moduledoc gracefully.
- **The help task listing itself**: `mix progen` should NOT appear in its own output (it's the root command, not a sub-task). Alternatively, it could appear — this is a minor design choice. Recommend excluding it since it's the command being run.
- **Third-party progen tasks**: If another package defines `mix progen.foo`, it will be discovered and shown. This is the intended behavior per the spec's "self-assembling" requirement.
- **Column width on narrow terminals**: With many tasks, the three-column layout could exceed 80 chars. Mitigate by truncating descriptions if needed, or accept slight overflow for very long task names.

## Testing Strategy

- **Unit tests**: Capture IO output from `Mix.Tasks.Progen.run([])` and assert on content (task names, group headers, descriptions).
- **Manual verification**: Run `mix progen` in the project and visually inspect alignment and grouping.
- **Regression**: Run `mix test` to ensure nothing is broken.

## Open Questions

- [x] Should `mix progen` itself appear in its own help output? Recommend no — it's the root help command.  Answer: NO
- [x] What visual format for group headers? Options: `=== progen.action ===`, `progen.action:`, or a simple underlined header. Suggest matching the `mix hex` style.  Answer: forget about headers - just a blank-line separator will do.
- [x] Should the args column be included, or just task name + description? The spec says to include argument signatures, but this makes alignment trickier. Recommend including args as a middle column if space allows, otherwise append to task name.  Answer: append args to task name, just use two columns.
