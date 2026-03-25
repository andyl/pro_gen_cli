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
      deps_dir
      |> Path.join("*/ebin")
      |> Path.wildcard()
      |> Enum.each(&Code.prepend_path/1)
    end

    :ok
  end
end
