defmodule Mix.Tasks.Progen.Validate.Edit do
  @shortdoc "Open a ProGen validator's source in $EDITOR"

  @moduledoc """
  Opens the source file of a ProGen validator in your editor.

  ```bash
  mix progen.validate.edit <validator>
  ```

  Accepts both string form (`filesys`) and module form (`Filesys`).

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

        case ProGen.Validations.validation_module(name) do
          {:ok, mod} ->
            open_source(name, mod)

          :error ->
            Mix.raise("Unknown validator: #{inspect(name)}")
        end

      [] ->
        Mix.raise("Usage: mix progen.validate.edit <validator>")
    end
  end

  defp open_source(name, mod) do
    case ProGen.CLI.source_path(mod) do
      {:ok, path} ->
        if File.exists?(path) do
          editor = System.get_env("EDITOR") || "vim"
          System.cmd(editor, [path])
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
