defmodule ProGen.CLI.InstallTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @moduletag :tmp_dir

  # Use the local pro_gen as a path dep so tests never hit the network
  @pro_gen_path Path.expand("../pro_gen", File.cwd!())

  setup %{tmp_dir: tmp_dir} do
    config_dir = Path.join(tmp_dir, "pro_gen")
    deps_dir = Path.join(config_dir, "deps")
    File.mkdir_p!(config_dir)
    Application.put_env(:pro_gen_cli, :config_dir, config_dir)

    on_exit(fn ->
      Application.delete_env(:pro_gen_cli, :config_dir)
    end)

    %{config_dir: config_dir, deps_dir: deps_dir}
  end

  defp write_local_config(config_dir) do
    yaml = """
    libs:
      - name: pro_gen
        path: #{@pro_gen_path}
    """

    File.write!(Path.join(config_dir, "config.yml"), yaml)
  end

  describe "config and validation errors (fast, no install)" do
    test "raises on invalid config", %{config_dir: config_dir} do
      yaml = """
      libs:
        - path: /tmp/no_name
      """

      File.write!(Path.join(config_dir, "config.yml"), yaml)

      assert_raise Mix.Error, ~r/missing required "name"/, fn ->
        capture_io(fn ->
          Mix.Tasks.Progen.Install.run([])
        end)
      end
    end

    test "raises on malformed YAML", %{config_dir: config_dir} do
      File.write!(Path.join(config_dir, "config.yml"), ":\nbad: [yaml\n")

      assert_raise Mix.Error, ~r/Failed to parse/, fn ->
        capture_io(fn ->
          Mix.Tasks.Progen.Install.run([])
        end)
      end
    end
  end

  describe "full install integration (slow)" do
    @tag :slow
    @tag timeout: 60_000
    test "installs, clears caches, and prints summary", %{
      config_dir: config_dir,
      deps_dir: deps_dir
    } do
      write_local_config(config_dir)

      # Seed persistent_term caches to verify they get cleared
      cache_keys = [
        {ProGen.Actions, :actions_list},
        {ProGen.Actions, :actions_map},
        {ProGen.Validations, :validations_list},
        {ProGen.Validations, :validations_map}
      ]

      Enum.each(cache_keys, &:persistent_term.put(&1, :test_sentinel))

      output =
        capture_io(fn ->
          Mix.Tasks.Progen.Install.run([])
        end)

      # Verify task output
      assert output =~ "Reading config..."
      assert output =~ "Installing ProGen + 1 libraries..."
      assert output =~ "Installed:"

      # Verify deps dir was populated
      assert File.dir?(deps_dir)

      # Verify caches were cleared
      Enum.each(cache_keys, fn key ->
        assert :persistent_term.get(key, :cleared) == :cleared
      end)
    end

    @tag :slow
    @tag timeout: 60_000
    test "--force reinstalls even when already present", %{
      config_dir: config_dir,
      deps_dir: deps_dir
    } do
      write_local_config(config_dir)

      # Pre-populate deps dir so it looks already installed
      File.mkdir_p!(Path.join([deps_dir, "pro_gen", "ebin"]))

      # Without force — should skip
      output_skip =
        capture_io(fn ->
          Mix.Tasks.Progen.Install.run([])
        end)

      assert output_skip =~ "Skipped"

      # With force — should reinstall
      output_force =
        capture_io(fn ->
          Mix.Tasks.Progen.Install.run(["--force"])
        end)

      assert output_force =~ "Installed:"
      assert File.dir?(Path.join(deps_dir, "pro_gen"))
    end
  end
end
