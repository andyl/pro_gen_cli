defmodule Mix.Tasks.Progen.Action.Edit do
  @shortdoc "Open a ProGen action's source in $EDITOR"

  @moduledoc """
  Opens the source file of a ProGen action in your editor.

  ```bash
  mix progen.action.edit <action>
  ```

  Accepts both string form (`io.echo`) and module form (`IO.Echo`).

  Only works for `path:` dependencies where the source file exists on disk.
  For `github:` or `hex:` dependencies, the source is not available and the
  command will print an error.
  """

  use Mix.Task

  @impl true
  def run(args) do
    ProGen.CLI.Bootstrap.ensure_loaded!()
    ProGen.CLI.maybe_start_app()

    case args do
      [ref | _] ->
        name = ProGen.CLI.resolve_name(ref)

        case ProGen.Actions.action_module(name) do
          {:ok, mod} ->
            open_source(name, mod)

          :error ->
            Mix.raise("Unknown action: #{inspect(name)}")
        end

      [] ->
        Mix.raise("Usage: mix progen.action.edit <action>")
    end
  end

  defp open_source(name, mod) do
    case ProGen.CLI.source_path(mod) do
      {:ok, path} ->
        if File.exists?(path) do
          [editor | args] = System.get_env("PROGEN_EDITOR") || "vim __FILE__"
                   |> String.replace("__FILE__", path)
                   |> String.split()
          System.cmd(editor, args)
        else
          Mix.raise(
            ~s(Cannot edit "#{name}": source not available.\nOnly path: dependencies can be edited.)
          )
        end

      {:error, msg} ->
        Mix.raise(msg)
    end
  end
end
