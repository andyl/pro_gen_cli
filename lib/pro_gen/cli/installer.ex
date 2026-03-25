defmodule ProGen.CLI.Installer do
  @moduledoc """
  Orchestrates the install workflow for ProGen and configured libraries.

  Creates a temporary Mix project with all configured deps, runs
  `mix deps.get && mix deps.compile`, then copies or symlinks ebin
  directories into `~/.config/pro_gen/deps/`.

  For `path:` deps, creates symlinks to the source project's ebin so that
  recompiling the source immediately reflects in the global install.
  """

  alias ProGen.CLI.GlobalConfig

  @doc """
  Installs ProGen and configured libraries.

  Takes a list of lib configs from `GlobalConfig.validate/1` and an options
  keyword list. Supports `force: true` to re-install everything.

  Returns `{:ok, summary}` or `{:error, summary}` where summary is
  `%{installed: [...], skipped: [...], failed: [...]}`.
  """
  def install(libs, opts \\ []) do
    force = Keyword.get(opts, :force, false)
    deps_dir = GlobalConfig.deps_dir()
    File.mkdir_p!(deps_dir)

    temp_dir = create_temp_dir()

    try do
      dep_specs = build_dep_specs(libs)
      write_temp_mixfile(temp_dir, dep_specs)

      with :ok <- run_mix(temp_dir, ["deps.get"]),
           :ok <- run_mix(temp_dir, ["deps.compile", "--force"]) do
        summary = install_ebins(temp_dir, libs, deps_dir, force)

        if summary.failed == [] do
          {:ok, summary}
        else
          {:error, summary}
        end
      else
        {:error, reason} ->
          {:error, %{installed: [], skipped: [], failed: [{"mix", reason}]}}
      end
    after
      File.rm_rf!(temp_dir)
    end
  end

  # -- Temp project --

  defp create_temp_dir do
    id = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    dir = Path.join(System.tmp_dir!(), "progen_install_#{id}")
    File.mkdir_p!(dir)
    dir
  end

  @doc false
  def build_dep_specs(libs) do
    # Start with default pro_gen from github
    base = [~s({:pro_gen, github: "andyl/pro_gen"})]

    # Build user-configured deps, potentially overriding pro_gen
    {has_pro_gen_override, user_deps} =
      Enum.reduce(libs, {false, []}, fn lib, {override, acc} ->
        dep = format_dep(lib)

        if lib.name == "pro_gen" do
          {true, [dep | acc]}
        else
          {override, [dep | acc]}
        end
      end)

    deps =
      if has_pro_gen_override do
        # User's pro_gen config replaces the default github ref
        Enum.reverse(user_deps)
      else
        base ++ Enum.reverse(user_deps)
      end

    Enum.join(deps, ",\n      ")
  end

  defp format_dep(%{name: name, source: {:path, path}}) do
    ~s({:#{name}, path: "#{path}"})
  end

  defp format_dep(%{name: name, source: {:github, repo}}) do
    ~s({:#{name}, github: "#{repo}"})
  end

  defp format_dep(%{name: name, source: {:hex, _pkg, version}}) do
    ~s({:#{name}, "#{version}"})
  end

  @doc false
  def build_temp_mixfile(dep_specs) do
    """
    defmodule ProgenInstall.MixProject do
      use Mix.Project

      def project do
        [
          app: :progen_install,
          version: "0.0.1",
          elixir: "~> 1.19",
          deps: deps()
        ]
      end

      defp deps do
        [
          #{dep_specs}
        ]
      end
    end
    """
  end

  defp write_temp_mixfile(temp_dir, dep_specs) do
    content = build_temp_mixfile(dep_specs)
    File.write!(Path.join(temp_dir, "mix.exs"), content)
  end

  # -- Mix commands --

  defp run_mix(temp_dir, args) do
    case System.cmd("mix", args, cd: temp_dir, stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, code} -> {:error, "mix #{Enum.join(args, " ")} failed (exit #{code}):\n#{output}"}
    end
  end

  # -- Ebin installation --

  defp install_ebins(temp_dir, libs, deps_dir, force) do
    # Build a map of lib name -> source type for path dep detection
    path_deps = Map.new(libs, fn lib -> {lib.name, lib.source} end)

    build_dir = Path.join([temp_dir, "_build", "dev", "lib"])

    # Install ALL compiled deps (including transitive), not just explicitly
    # named ones. This ensures runtime deps like yaml_elixir are available
    # via the bootstrap code path. Exclude only the temp project itself.
    ebin_dirs =
      if File.dir?(build_dir) do
        build_dir
        |> File.ls!()
        |> Enum.reject(fn name -> name == "progen_install" end)
        |> Enum.filter(fn name ->
          File.dir?(Path.join([build_dir, name, "ebin"]))
        end)
      else
        []
      end

    Enum.reduce(ebin_dirs, %{installed: [], skipped: [], failed: []}, fn name, summary ->
      target = Path.join(deps_dir, name)
      source_ebin = Path.join([build_dir, name, "ebin"])

      cond do
        !force && already_installed?(target) ->
          %{summary | skipped: [name | summary.skipped]}

        true ->
          try do
            install_one(name, source_ebin, target, Map.get(path_deps, name))
            %{summary | installed: [name | summary.installed]}
          rescue
            e ->
              %{summary | failed: [{name, Exception.message(e)} | summary.failed]}
          end
      end
    end)
    |> then(fn summary ->
      %{
        installed: Enum.reverse(summary.installed),
        skipped: Enum.reverse(summary.skipped),
        failed: Enum.reverse(summary.failed)
      }
    end)
  end

  defp install_one(name, source_ebin, target, source) do
    # Remove existing target to ensure clean state
    File.rm_rf!(target)
    File.mkdir_p!(target)

    case source do
      {:path, path} ->
        # Compile the source project so beams are up-to-date before symlinking
        System.cmd("mix", ["compile"], cd: path, stderr_to_stdout: true)

        # Symlink to source project's ebin for live recompile workflow
        real_ebin = Path.join([path, "_build", "dev", "lib", name, "ebin"])

        if File.dir?(real_ebin) do
          # Symlink target ebin -> source project's ebin
          File.ln_s!(real_ebin, Path.join(target, "ebin"))
        else
          # Source not compiled yet; copy from temp project as fallback
          File.cp_r!(source_ebin, Path.join(target, "ebin"))
        end

      _ ->
        # Copy ebin for github/hex deps
        File.cp_r!(source_ebin, Path.join(target, "ebin"))
    end
  end

  @doc false
  def already_installed?(target) do
    ebin = Path.join(target, "ebin")
    File.dir?(ebin) || is_symlink?(ebin)
  end

  defp is_symlink?(path) do
    case File.lstat(path) do
      {:ok, %{type: :symlink}} -> true
      _ -> false
    end
  end
end
