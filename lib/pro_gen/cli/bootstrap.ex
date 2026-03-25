defmodule ProGen.CLI.Bootstrap do
  @moduledoc """
  Loads ProGen modules from `~/.config/pro_gen/deps/` at runtime.

  Every Mix task calls `ensure_loaded!/0` as its first step. When running
  inside a Mix project that depends on `pro_gen`, the modules are already
  loaded and this is a fast no-op. When running from the global archive,
  this prepends the installed ebin paths so the BEAM can find them.
  """

  alias ProGen.CLI.GlobalConfig

  @doc """
  Ensures ProGen modules are available, loading from deps dir if needed.

  For `path:` dependencies installed as symlinks, recompiles the source
  project first so edited source files are reflected immediately.

  Raises if modules cannot be found after loading.
  """
  def ensure_loaded! do
    if Code.ensure_loaded?(ProGen.Actions) do
      :ok
    else
      recompile_path_deps()
      load_deps()

      if Code.ensure_loaded?(ProGen.Actions) do
        :ok
      else
        Mix.raise("""
        ProGen is not installed. Run:

            mix progen.install
        """)
      end
    end
  end

  @doc """
  Prepends all `<deps_dir>/*/ebin` directories to the code path.

  Returns `:ok`.
  """
  def load_deps do
    deps_dir = GlobalConfig.deps_dir()

    if File.dir?(deps_dir) do
      ebin_dirs =
        deps_dir
        |> Path.join("*/ebin")
        |> Path.wildcard()

      # Add code paths so modules are loadable
      Enum.each(ebin_dirs, &Code.prepend_path/1)

      # Load OTP applications so module discovery via
      # Application.loaded_applications() works
      for ebin <- ebin_dirs,
          app_file <- Path.wildcard(Path.join(ebin, "*.app")),
          app_name = app_file |> Path.basename(".app") |> String.to_atom() do
        Application.load(app_name)
      end
    end

    :ok
  end

  @doc """
  Recompiles `path:` dependencies whose ebin dirs are symlinked.

  Scans `~/.config/pro_gen/deps/*/ebin` for symlinks, derives the source
  Mix project root from each target, and runs `mix compile` there. This
  ensures that source edits (e.g. via `mix progen.action.edit`) are
  compiled into fresh beam files before they are loaded.

  No-op when no symlinked ebin dirs exist.
  """
  def recompile_path_deps do
    deps_dir = GlobalConfig.deps_dir()

    if File.dir?(deps_dir) do
      deps_dir
      |> File.ls!()
      |> Enum.each(fn dep_name ->
        ebin = Path.join([deps_dir, dep_name, "ebin"])

        with {:ok, target} <- File.read_link(ebin),
             abs_target = resolve_path(target, Path.dirname(ebin)),
             root when root != nil <- project_root_from_ebin(abs_target) do
          System.cmd("mix", ["compile"], cd: root, stderr_to_stdout: true)
        end
      end)
    end

    :ok
  end

  # Resolves a potentially relative symlink target to an absolute path.
  defp resolve_path(target, base_dir) do
    if Path.type(target) == :absolute do
      target
    else
      Path.expand(target, base_dir)
    end
  end

  # Derives the Mix project root from an ebin path.
  #
  # Standard layout: <project>/_build/<env>/lib/<app>/ebin
  # So the project root is 5 directories up.
  defp project_root_from_ebin(ebin_path) do
    root =
      ebin_path
      |> Path.dirname()
      |> Path.dirname()
      |> Path.dirname()
      |> Path.dirname()
      |> Path.dirname()

    if File.exists?(Path.join(root, "mix.exs")), do: root
  end
end
