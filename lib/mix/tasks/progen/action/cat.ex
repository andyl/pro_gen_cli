defmodule Mix.Tasks.Progen.Action.Cat do
  @shortdoc "Print the source code of a ProGen action"

  @moduledoc """
  Prints the source code of a ProGen action module to stdout.

  ```bash
  mix progen.action.cat <action>
  ```

  Accepts both string form (`io.echo`) and module form (`IO.Echo`).
  """

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [ref | _] ->
        name = ProGen.CLI.resolve_name(ref)

        case ProGen.Actions.action_module(name) do
          {:ok, mod} ->
            case ProGen.CLI.source_path(mod) do
              {:ok, path} ->
                case File.read(path) do
                  {:ok, contents} -> Mix.shell().info(contents)
                  {:error, reason} -> Mix.raise("Cannot read #{path}: #{reason}")
                end

              {:error, msg} ->
                Mix.raise(msg)
            end

          :error ->
            Mix.raise("Unknown action: #{inspect(name)}")
        end

      [] ->
        Mix.raise("Usage: mix progen.action.cat <action>")
    end
  end
end
