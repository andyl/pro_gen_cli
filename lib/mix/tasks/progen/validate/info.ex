defmodule Mix.Tasks.Progen.Validate.Info do
  @shortdoc "Show metadata for a ProGen validator"

  @moduledoc """
  Displays metadata for a registered ProGen validator.

  ```bash
  mix progen.validate.info <validator>
  ```

  Accepts both string form (`filesys`) and module form (`Filesys`).

  Shows: module name, string name, description, source file, and
  available checks.
  """

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [ref | _] ->
        name = ProGen.CLI.resolve_name(ref)

        case ProGen.Validations.validation_info(name) do
          {:ok, info} ->
            print_info(info)

          {:error, msg} ->
            Mix.raise(msg)
        end

      [] ->
        Mix.raise("Usage: mix progen.validate.info <validator>")
    end
  end

  defp print_info(info) do
    mod = info.module

    source =
      case ProGen.CLI.source_path(mod) do
        {:ok, path} -> path
        {:error, _} -> "(unavailable)"
      end

    lines = [
      "Module:      #{inspect(mod)}",
      "Name:        #{info.name}",
      "Description: #{info.description}",
      "Source:      #{source}",
      "",
      "Checks:",
      format_checks(info.checks)
    ]

    Mix.shell().info(Enum.join(lines, "\n"))
  end

  defp format_checks([]), do: "  (none)"

  defp format_checks(checks) do
    Enum.map_join(checks, "\n", fn
      {name, doc} -> "  #{name} — #{doc}"
      name when is_atom(name) -> "  #{name}"
    end)
  end
end
