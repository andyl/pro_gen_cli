defmodule Mix.Tasks.Progen.Action.Run do
  @shortdoc "Run a ProGen action"

  @moduledoc """
  Runs a named ProGen action with optional key=value arguments.

  ```bash
  mix progen.action.run "commit message" <action> [key=value ...]
  ```

  The first argument is the commit message / description. The second is the
  action name. Remaining arguments are key=value pairs parsed into a keyword
  list and passed to `ProGen.Actions.run/2`.

  After a successful run, auto-commits using the same logic as
  `ProGen.Script.action/3`. Pass `commit=false` to suppress auto-commit.

  Accepts both string form (`io.echo`) and module form (`IO.Echo`).
  """

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [desc, ref | kv_args] ->
        name = ProGen.CLI.resolve_name(ref)
        action_opts = ProGen.CLI.parse_kv_args(kv_args)

        {commit_opts, action_opts} = Keyword.split(action_opts, [:commit])

        commit_opts =
          case commit_opts do
            [commit: "false"] -> [commit: false]
            other -> other
          end

        commit_type =
          case ProGen.Actions.action_module(name) do
            {:ok, mod} -> mod.commit_type()
            :error -> "chore(action)"
          end

        case ProGen.Actions.run(name, action_opts) do
          {:error, msg} ->
            error_msg = enrich_error(name, msg)
            Mix.raise(error_msg)

          _ok ->
            ProGen.AutoCommit.auto_commit(desc, commit_type, commit_opts)
        end

      _ ->
        Mix.raise("Usage: mix progen.action.run \"message\" <action> [key=value ...]")
    end
  end

  defp enrich_error(name, msg) do
    case ProGen.Actions.action_module(name) do
      {:ok, mod} ->
        usage = mod.usage()

        if usage != "" do
          "#{msg}\n\nUsage for #{name}:\n#{usage}"
        else
          msg
        end

      :error ->
        msg
    end
  end
end
