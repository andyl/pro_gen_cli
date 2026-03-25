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

  Raises if modules cannot be found after loading.
  """
  def ensure_loaded! do
    if Code.ensure_loaded?(ProGen.Actions) do
      :ok
    else
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
end
