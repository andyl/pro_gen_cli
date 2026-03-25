defmodule ProGen.CLI.BootstrapTest do
  use ExUnit.Case, async: false

  alias ProGen.CLI.Bootstrap

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    config_dir = Path.join(tmp_dir, "pro_gen")
    deps_dir = Path.join(config_dir, "deps")
    File.mkdir_p!(deps_dir)
    Application.put_env(:pro_gen_cli, :config_dir, config_dir)

    on_exit(fn ->
      Application.delete_env(:pro_gen_cli, :config_dir)
    end)

    %{config_dir: config_dir, deps_dir: deps_dir}
  end

  describe "load_deps/0" do
    test "prepends ebin paths found in deps dir", %{deps_dir: deps_dir} do
      # Create mock ebin directories
      ebin1 = Path.join([deps_dir, "lib_a", "ebin"])
      ebin2 = Path.join([deps_dir, "lib_b", "ebin"])
      File.mkdir_p!(ebin1)
      File.mkdir_p!(ebin2)

      assert :ok = Bootstrap.load_deps()

      code_paths = :code.get_path() |> Enum.map(&to_string/1)
      assert ebin1 in code_paths
      assert ebin2 in code_paths
    end

    test "returns :ok when deps dir does not exist", %{config_dir: config_dir} do
      # Point to a non-existent deps dir
      File.rm_rf!(Path.join(config_dir, "deps"))
      assert :ok = Bootstrap.load_deps()
    end

    test "returns :ok when deps dir is empty", %{deps_dir: _deps_dir} do
      assert :ok = Bootstrap.load_deps()
    end

    test "loads OTP applications from .app files", %{deps_dir: deps_dir} do
      # Create a mock dep with a .app file
      ebin = Path.join([deps_dir, "mock_app", "ebin"])
      File.mkdir_p!(ebin)

      app_spec =
        {:application, :progen_test_mock_app,
         [vsn: ~c"0.1.0", modules: [], applications: [:kernel, :stdlib]]}

      File.write!(Path.join(ebin, "progen_test_mock_app.app"), :io_lib.format("~p.", [app_spec]))

      Bootstrap.load_deps()

      loaded_apps = Application.loaded_applications() |> Enum.map(&elem(&1, 0))
      assert :progen_test_mock_app in loaded_apps

      # Clean up
      Application.unload(:progen_test_mock_app)
    end
  end

  describe "ensure_loaded!/0" do
    test "returns :ok when ProGen.Actions is already loaded" do
      # ProGen.Actions is available because pro_gen is a compile-time dep
      assert :ok = Bootstrap.ensure_loaded!()
    end
  end
end
