defmodule Mix.Tasks.Progen.Install do
  @shortdoc "Install ProGen and configured libraries globally"

  @moduledoc """
  Installs ProGen and configured libraries into `~/.config/pro_gen/deps/`.

  ```bash
  mix progen.install [--force]
  ```

  Reads `~/.config/pro_gen/config.yml` for library configuration, creates a
  temporary Mix project to fetch and compile all deps, then copies or symlinks
  ebin directories into the global deps dir.

  ## Options

    * `--force` — re-install all libraries even if already present
  """

  use Mix.Task

  alias ProGen.CLI.{Bootstrap, GlobalConfig, Installer}

  # Cache clearing now delegated to the core library's public API.
  # Kept as a fallback list in case the module isn't loaded yet.

  @impl true
  def run(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: [force: :boolean])
    force = Keyword.get(opts, :force, false)

    # Load any previously installed deps first — this makes yaml_elixir
    # available for config parsing on subsequent installs.
    Bootstrap.load_deps()

    Mix.shell().info("Reading config...")

    config =
      try do
        case GlobalConfig.read() do
          {:ok, config} -> config
          {:error, msg} -> Mix.raise(msg)
        end
      rescue
        UndefinedFunctionError ->
          Mix.raise("""
          Cannot parse config.yml: YAML parser not yet installed.

          Remove or rename your config file, run `mix progen.install` to install
          ProGen core first, then restore your config and run again.
          """)
      end

    libs =
      case GlobalConfig.validate(config) do
        {:ok, libs} -> libs
        {:error, msg} -> Mix.raise(msg)
      end

    lib_count = length(libs)
    label = if lib_count == 0, do: "ProGen core", else: "ProGen + #{lib_count} libraries"
    Mix.shell().info("Installing #{label}...")

    summary =
      case Installer.install(libs, force: force) do
        {:ok, summary} -> summary
        {:error, summary} -> summary
      end

    Bootstrap.load_deps()
    clear_caches()

    primary_names = MapSet.new(["pro_gen" | Enum.map(libs, & &1.name)])
    print_summary(summary, primary_names)

    if summary.failed != [] do
      Mix.raise("Some libraries failed to install (see above)")
    end
  end

  defp clear_caches do
    ProGen.Actions.clear_cache()
    ProGen.Validations.clear_cache()
  end

  defp print_summary(summary, primary_names) do
    if summary.installed != [] do
      Mix.shell().info("Installed: #{format_names(summary.installed, primary_names)}")
    end

    if summary.skipped != [] do
      Mix.shell().info("Skipped (up to date): #{format_names(summary.skipped, primary_names)}")
    end

    Enum.each(summary.failed, fn {name, reason} ->
      Mix.shell().error("Failed: #{name} — #{reason}")
    end)

    if summary.installed == [] and summary.skipped == [] and summary.failed == [] do
      Mix.shell().info("Nothing to install.")
    end
  end

  defp format_names(names, primary_names) do
    {primary, transitive} =
      Enum.split_with(names, &MapSet.member?(primary_names, &1))

    cond do
      primary != [] && transitive != [] ->
        "#{Enum.join(primary, ", ")} (+ #{length(transitive)} dependencies)"

      primary != [] ->
        Enum.join(primary, ", ")

      true ->
        "#{length(transitive)} dependencies"
    end
  end
end
