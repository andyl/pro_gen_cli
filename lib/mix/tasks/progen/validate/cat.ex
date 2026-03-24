defmodule Mix.Tasks.Progen.Validate.Cat do
  @shortdoc "Print the source code of a ProGen validator"

  @moduledoc """
  Prints the source code of a ProGen validator module to stdout.

  ```bash
  mix progen.validate.cat <validator>
  ```

  Accepts both string form (`filesys`) and module form (`Filesys`).
  """

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [ref | _] ->
        name = ProGen.CLI.resolve_name(ref)

        case ProGen.Validations.validation_module(name) do
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
            Mix.raise("Unknown validator: #{inspect(name)}")
        end

      [] ->
        Mix.raise("Usage: mix progen.validate.cat <validator>")
    end
  end
end
