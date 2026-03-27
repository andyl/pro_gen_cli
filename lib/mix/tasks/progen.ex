defmodule Mix.Tasks.Progen do
  @shortdoc "Print help for all progen tasks"

  @moduledoc """
  Lists all available `progen.*` Mix tasks with their usage and descriptions.

  ```bash
  mix progen
  ```

  Tasks are grouped by namespace and sorted alphabetically.
  """

  use Mix.Task

  @impl true
  def run(_args) do
    tasks = discover_tasks()
    output = format_output(tasks)
    Mix.shell().info(output)
  end

  defp discover_tasks do
    Mix.Task.load_all()

    Mix.Task.all_modules()
    |> Enum.map(fn mod -> {Mix.Task.task_name(mod), mod} end)
    |> Enum.filter(fn {name, _mod} -> String.starts_with?(name, "progen.") end)
    |> Enum.map(fn {name, mod} ->
      %{
        name: name,
        shortdoc: Mix.Task.shortdoc(mod) || "",
        args: extract_args(mod, name)
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp extract_args(mod, task_name) do
    case Code.fetch_docs(mod) do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} ->
        parse_usage_line(moduledoc, task_name)

      _ ->
        ""
    end
  end

  defp parse_usage_line(moduledoc, task_name) do
    prefix = "mix #{task_name}"

    moduledoc
    |> String.split("\n")
    |> Enum.find(fn line -> String.contains?(line, prefix) end)
    |> case do
      nil -> ""
      line -> line |> String.trim() |> String.replace_prefix(prefix, "") |> String.trim()
    end
  end

  defp format_output(tasks) do
    grouped =
      tasks
      |> Enum.group_by(fn %{name: name} ->
        parts = String.split(name, ".")

        case parts do
          [_, _] -> "progen"
          [_, group | _] -> "progen.#{group}"
        end
      end)
      |> Enum.sort_by(fn {group, _} -> group end)

    max_name_width =
      tasks
      |> Enum.map(fn %{name: name, args: args} ->
        label = "mix #{name}" <> if(args != "", do: " #{args}", else: "")
        String.length(label)
      end)
      |> Enum.max(fn -> 0 end)

    pad = max_name_width + 2

    sections =
      Enum.map(grouped, fn {_group, group_tasks} ->
        group_tasks
        |> Enum.map(fn %{name: name, shortdoc: desc, args: args} ->
          label = "mix #{name}" <> if(args != "", do: " #{args}", else: "")
          "  #{String.pad_trailing(label, pad)}#{desc}"
        end)
        |> Enum.join("\n")
      end)

    "ProGen — available tasks:\n\n" <> Enum.join(sections, "\n\n")
  end
end
