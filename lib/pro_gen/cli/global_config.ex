defmodule ProGen.CLI.GlobalConfig do
  @moduledoc """
  Reads and validates `~/.config/pro_gen/config.yml` for global library configuration.

  The config file declares third-party action/validation libraries that
  `mix progen.install` fetches and compiles into `~/.config/pro_gen/deps/`.

  ## Config format

      libs:
        - name: my_actions
          path: /home/user/src/my_actions
        - name: team_utils
          github: myorg/pro_gen_utils
        - name: community_pack
          hex: pro_gen_community
          version: "~> 0.2"
  """

  @doc """
  Returns the base config directory path.

  Defaults to `~/.config/pro_gen`. Override in tests via application env:

      Application.put_env(:pro_gen_cli, :config_dir, "/tmp/test_config")
  """
  def config_dir do
    Application.get_env(:pro_gen_cli, :config_dir) || Path.expand("~/.config/pro_gen")
  end

  @doc """
  Returns the deps directory path (`<config_dir>/deps`).
  """
  def deps_dir do
    Path.join(config_dir(), "deps")
  end

  @doc """
  Returns the path to the config file, checking `.yml` then `.yaml`.

  Returns `nil` if neither exists.
  """
  def config_path do
    dir = config_dir()

    yml = Path.join(dir, "config.yml")
    yaml = Path.join(dir, "config.yaml")

    cond do
      File.exists?(yml) -> yml
      File.exists?(yaml) -> yaml
      true -> nil
    end
  end

  @doc """
  Reads and parses the global config file.

  Returns `{:ok, config_map}` or `{:error, message}`.
  If no config file exists, returns `{:ok, %{libs: []}}`.
  """
  def read do
    case config_path() do
      nil ->
        {:ok, %{libs: []}}

      path ->
        case YamlElixir.read_from_file(path) do
          {:ok, nil} ->
            {:ok, %{libs: []}}

          {:ok, parsed} when is_map(parsed) ->
            {:ok, normalize(parsed)}

          {:ok, _other} ->
            {:error, "Config file must contain a YAML mapping, got: #{path}"}

          {:error, %YamlElixir.ParsingError{} = err} ->
            {:error, "Failed to parse #{path}: #{Exception.message(err)}"}
        end
    end
  end

  @doc """
  Validates the parsed config structure.

  `libs:` must be a list where each entry has a `name` (string) and exactly one
  source key (`path:`, `github:`, or `hex:` with required `version:`).

  Returns `{:ok, libs}` or `{:error, message}` where `libs` is a list of maps:

      [
        %{name: "my_actions", source: {:path, "/home/user/src/my_actions"}},
        %{name: "team_utils", source: {:github, "myorg/pro_gen_utils"}},
        %{name: "community_pack", source: {:hex, "pro_gen_community", "~> 0.2"}}
      ]
  """
  def validate(%{libs: libs}) when is_list(libs) do
    results = Enum.with_index(libs, 1) |> Enum.map(&validate_lib/1)

    case Enum.filter(results, &match?({:error, _}, &1)) do
      [] -> {:ok, Enum.map(results, fn {:ok, lib} -> lib end)}
      errors -> {:error, Enum.map_join(errors, "\n", fn {:error, msg} -> msg end)}
    end
  end

  def validate(%{libs: _}) do
    {:error, "\"libs\" must be a list"}
  end

  def validate(%{}) do
    {:ok, []}
  end

  # -- Private --

  defp normalize(parsed) do
    libs = Map.get(parsed, "libs") || []
    %{libs: libs}
  end

  defp validate_lib({entry, index}) when is_map(entry) do
    with {:ok, name} <- require_name(entry, index),
         {:ok, source} <- require_source(entry, name) do
      {:ok, %{name: name, source: source}}
    end
  end

  defp validate_lib({_entry, index}) do
    {:error, "libs[#{index}]: each entry must be a map"}
  end

  defp require_name(entry, index) do
    case Map.get(entry, "name") do
      nil -> {:error, "libs[#{index}]: missing required \"name\" field"}
      name when is_binary(name) -> {:ok, name}
      _ -> {:error, "libs[#{index}]: \"name\" must be a string"}
    end
  end

  defp require_source(entry, name) do
    sources =
      Enum.filter(
        [
          if(Map.has_key?(entry, "path"), do: :path),
          if(Map.has_key?(entry, "github"), do: :github),
          if(Map.has_key?(entry, "hex"), do: :hex)
        ],
        & &1
      )

    case sources do
      [] ->
        {:error, "\"#{name}\": must have exactly one source (path, github, or hex)"}

      [_, _ | _] ->
        {:error,
         "\"#{name}\": must have exactly one source (path, github, or hex), got: #{Enum.join(sources, ", ")}"}

      [:path] ->
        {:ok, {:path, Map.fetch!(entry, "path")}}

      [:github] ->
        {:ok, {:github, Map.fetch!(entry, "github")}}

      [:hex] ->
        case Map.get(entry, "version") do
          nil ->
            {:error, "\"#{name}\": hex deps require a \"version\" field"}

          version when is_binary(version) ->
            {:ok, {:hex, Map.fetch!(entry, "hex"), version}}

          _ ->
            {:error, "\"#{name}\": \"version\" must be a string"}
        end
    end
  end
end
