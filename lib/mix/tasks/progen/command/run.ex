defmodule Mix.Tasks.Progen.Command.Run do
  @shortdoc "Run a shell command with auto-commit"

  @moduledoc """
  Runs a shell command with a description and auto-commits on success.

  ```bash
  mix progen.command.run "message" "command"
  ```

  The first argument is the commit message / description. The second is the
  shell command to execute via `ProGen.Sys.cmd/1`. After success, auto-commits
  with commit type `"chore(command)"`.
  """

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [desc, command | _] ->
        case ProGen.Sys.cmd(command) do
          :ok ->
            ProGen.AutoCommit.auto_commit(desc, "chore(command)")

          {:error, code} ->
            Mix.raise("Command failed with exit code #{code}")
        end

      _ ->
        Mix.raise("Usage: mix progen.command.run \"message\" \"command\"")
    end
  end
end
