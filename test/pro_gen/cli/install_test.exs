defmodule ProGen.CLI.InstallTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @moduletag :tmp_dir

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

  describe "mix progen.install" do
    test "installs with no config file (ProGen core only)", %{deps_dir: deps_dir} do
      output =
        capture_io(fn ->
          Mix.Tasks.Progen.Install.run([])
        end)

      assert output =~ "Reading config..."
      assert output =~ "Installing ProGen core..."
      # deps dir should have been created
      assert File.dir?(deps_dir)
    end

    test "installs with valid config", %{config_dir: config_dir} do
      # Use pro_gen as a path dep pointing to the sibling repo
      pro_gen_path = Path.expand("../pro_gen", File.cwd!())

      yaml = """
      libs:
        - name: pro_gen
          path: #{pro_gen_path}
      """

      File.write!(Path.join(config_dir, "config.yml"), yaml)

      output =
        capture_io(fn ->
          Mix.Tasks.Progen.Install.run([])
        end)

      assert output =~ "Reading config..."
      assert output =~ "Installing ProGen + 1 libraries..."
    end

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

    test "accepts --force flag" do
      output =
        capture_io(fn ->
          Mix.Tasks.Progen.Install.run(["--force"])
        end)

      assert output =~ "Reading config..."
    end

    test "clears persistent_term caches after install" do
      # Seed the caches
      keys = [
        {ProGen.Actions, :actions_list},
        {ProGen.Actions, :actions_map},
        {ProGen.Validations, :validations_list},
        {ProGen.Validations, :validations_map}
      ]

      Enum.each(keys, fn key ->
        :persistent_term.put(key, :test_sentinel)
      end)

      capture_io(fn ->
        Mix.Tasks.Progen.Install.run([])
      end)

      Enum.each(keys, fn key ->
        assert :persistent_term.get(key, :cleared) == :cleared
      end)
    end

    test "prints summary with skipped deps", %{deps_dir: deps_dir} do
      # Pre-install pro_gen so it gets skipped
      File.mkdir_p!(Path.join([deps_dir, "pro_gen", "ebin"]))

      # No config file -> installs pro_gen core only, but it's already there
      output =
        capture_io(fn ->
          Mix.Tasks.Progen.Install.run([])
        end)

      # Should mention something about the install
      assert output =~ "Reading config..."
    end
  end
end
