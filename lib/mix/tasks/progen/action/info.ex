defmodule Mix.Tasks.Progen.Action.Info do
  @shortdoc "Show metadata for a ProGen action"

  @moduledoc """
  Displays metadata for a registered ProGen action.

  ```bash
  mix progen.action.info <action>
  ```

  Accepts both string form (`deps.install`) and module form (`Deps.Install`).

  Shows: module name, string name, description, source file, arguments,
  commit type, dependencies, validations, and usage.
  """

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [ref | _] ->
        name = ProGen.CLI.resolve_name(ref)

        case ProGen.Actions.action_info(name) do
          {:ok, info} ->
            print_info(info)

          {:error, msg} ->
            Mix.raise(msg)
        end

      [] ->
        Mix.raise("Usage: mix progen.action.info <action>")
    end
  end

  defp print_info(info) do
    mod = info.module
    deps = mod.depends_on([])

    source =
      case ProGen.CLI.source_path(mod) do
        {:ok, path} -> path
        {:error, _} -> "(unavailable)"
      end

    lines = [
      "Module:       #{inspect(mod)}",
      "Name:         #{info.name}",
      "Description:  #{info.description}",
      "Source:       #{source}",
      "Commit type:  #{info.commit_type}",
      "Dependencies: #{format_deps(deps)}",
      "Validations:  #{format_validations(info.validate)}",
      "",
      "Arguments:",
      format_opts_def(info.opts_def),
      "",
      "Usage:",
      info.usage
    ]

    Mix.shell().info(Enum.join(lines, "\n"))
  end

  defp format_deps([]), do: "(none)"
  defp format_deps(deps), do: Enum.map_join(deps, ", ", &format_dep/1)

  defp format_dep({name, _opts}) when is_binary(name), do: name
  defp format_dep(name) when is_binary(name), do: name

  defp format_validations([]), do: "(none)"

  defp format_validations(validations) do
    Enum.map_join(validations, ", ", fn {name, checks} ->
      "#{name}(#{Enum.join(Enum.map(checks, &inspect/1), ", ")})"
    end)
  end

  defp format_opts_def([]), do: "  (none)"

  defp format_opts_def(opts_def) do
    Enum.map_join(opts_def, "\n", fn {key, config} ->
      type = Keyword.get(config, :type, :string)
      required = if Keyword.get(config, :required, false), do: " (required)", else: ""
      doc = Keyword.get(config, :doc, "")
      "  #{key}: #{type}#{required} — #{doc}"
    end)
  end
end
