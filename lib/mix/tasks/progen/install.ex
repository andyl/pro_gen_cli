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

  @cache_keys [
    {ProGen.Actions, :actions_list},
    {ProGen.Actions, :actions_map},
    {ProGen.Validations, :validations_list},
    {ProGen.Validations, :validations_map}
  ]

  @impl true
  def run(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: [force: :boolean])
    force = Keyword.get(opts, :force, false)

    Mix.shell().info("Reading config...")

    config =
      case GlobalConfig.read() do
        {:ok, config} -> config
        {:error, msg} -> Mix.raise(msg)
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
    print_summary(summary)

    if summary.failed != [] do
      Mix.raise("Some libraries failed to install (see above)")
    end
  end

  defp clear_caches do
    Enum.each(@cache_keys, fn key ->
      try do
        :persistent_term.erase(key)
      rescue
        ArgumentError -> :ok
      end
    end)
  end

  defp print_summary(summary) do
    if summary.installed != [] do
      Mix.shell().info("Installed: #{Enum.join(summary.installed, ", ")}")
    end

    if summary.skipped != [] do
      Mix.shell().info("Skipped (up to date): #{Enum.join(summary.skipped, ", ")}")
    end

    Enum.each(summary.failed, fn {name, reason} ->
      Mix.shell().error("Failed: #{name} — #{reason}")
    end)

    if summary.installed == [] and summary.skipped == [] and summary.failed == [] do
      Mix.shell().info("Nothing to install.")
    end
  end
end
