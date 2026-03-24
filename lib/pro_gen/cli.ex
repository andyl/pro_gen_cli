defmodule ProGen.CLI do
  @moduledoc """
  Shared helpers for ProGen Mix tasks.

  Provides name resolution, argument parsing, output formatting,
  and source path lookup used by all `mix progen.*` tasks.
  """

  @doc """
  Resolves an action or validation name reference.

  If the reference contains an uppercase letter, it is treated as module form:
  split on `.`, apply `Macro.underscore/1` to each segment, rejoin with `.`.
  Otherwise returned as-is.

  ## Examples

      iex> ProGen.CLI.resolve_name("io.echo")
      "io.echo"

      iex> ProGen.CLI.resolve_name("IO.Echo")
      "io.echo"

      iex> ProGen.CLI.resolve_name("Deps.Install")
      "deps.install"
  """
  def resolve_name(ref) when is_binary(ref) do
    if ref =~ ~r/[A-Z]/ do
      ref
      |> String.split(".")
      |> Enum.map(&Macro.underscore/1)
      |> Enum.join(".")
    else
      ref
    end
  end

  @doc """
  Parses a list of `"key=value"` strings into a keyword list.

  Splits on the first `=` so values may contain `=` characters.
  Keys are converted to atoms. Raises `ArgumentError` if a string
  contains no `=`.

  ## Examples

      iex> ProGen.CLI.parse_kv_args(["project=my_app", "args=--no-ecto"])
      [project: "my_app", args: "--no-ecto"]

      iex> ProGen.CLI.parse_kv_args(["has_file=mix.exs"])
      [has_file: "mix.exs"]
  """
  def parse_kv_args(args) when is_list(args) do
    Enum.map(args, fn arg ->
      case String.split(arg, "=", parts: 2) do
        [key, value] ->
          {String.to_atom(key), value}

        [_no_equals] ->
          raise ArgumentError,
                "Invalid argument #{inspect(arg)}: expected key=value format"
      end
    end)
  end

  @doc """
  Parses validation check specifications from CLI args.

  Simple names (no `=`) become atoms. Names with `=` become
  `{:atom, "value"}` tuples.

  ## Examples

      iex> ProGen.CLI.parse_checks(["has_mix", "has_git"])
      [:has_mix, :has_git]

      iex> ProGen.CLI.parse_checks(["has_file=mix.exs"])
      [{:has_file, "mix.exs"}]
  """
  def parse_checks(args) when is_list(args) do
    Enum.map(args, fn arg ->
      case String.split(arg, "=", parts: 2) do
        [key, value] -> {String.to_atom(key), value}
        [name] -> String.to_atom(name)
      end
    end)
  end

  @doc """
  Returns the source file path for a compiled module.

  Returns `{:ok, path}` or `{:error, message}` if source info
  is not available.
  """
  def source_path(mod) do
    case mod.__info__(:compile)[:source] do
      nil -> {:error, "Source path not available for #{inspect(mod)}"}
      source -> {:ok, to_string(source)}
    end
  end

  @doc """
  Formats a list of `{name, description}` tuples as an aligned table string.
  """
  def format_table(rows) do
    case rows do
      [] ->
        ""

      rows ->
        max_name =
          rows
          |> Enum.map(fn {name, _} -> String.length(name) end)
          |> Enum.max()

        rows
        |> Enum.map_join("\n", fn {name, desc} ->
          String.pad_trailing(name, max_name) <> "  " <> desc
        end)
    end
  end

  @doc """
  Formats a list of `{name, description}` tuples as a JSON array.

  Uses the built-in `JSON` module (Elixir 1.19+).
  """
  def format_list_json(items) do
    items
    |> Enum.map(fn {name, desc} -> %{"name" => name, "description" => desc} end)
    |> JSON.encode!()
  end

  @doc """
  Formats a list of `{name, description}` tuples as plain text (one per line).
  """
  def format_list_text(items) do
    Enum.map_join(items, "\n", fn {name, _desc} -> name end)
  end
end
