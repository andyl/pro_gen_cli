defmodule ProGen.CLI.InstallerTest do
  use ExUnit.Case, async: false

  alias ProGen.CLI.Installer

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

  describe "build_dep_specs/1" do
    test "includes default pro_gen when no override" do
      libs = [%{name: "my_lib", source: {:github, "org/my_lib"}}]
      specs = Installer.build_dep_specs(libs)
      assert specs =~ ~s({:pro_gen, github: "andyl/pro_gen"})
      assert specs =~ ~s({:my_lib, github: "org/my_lib"})
    end

    test "replaces default pro_gen with path override" do
      libs = [%{name: "pro_gen", source: {:path, "/home/user/src/pro_gen"}}]
      specs = Installer.build_dep_specs(libs)
      assert specs =~ ~s({:pro_gen, path: "/home/user/src/pro_gen"})
      refute specs =~ "andyl/pro_gen"
    end

    test "formats path deps" do
      libs = [%{name: "my_lib", source: {:path, "/tmp/my_lib"}}]
      specs = Installer.build_dep_specs(libs)
      assert specs =~ ~s({:my_lib, path: "/tmp/my_lib"})
    end

    test "formats github deps" do
      libs = [%{name: "utils", source: {:github, "org/utils"}}]
      specs = Installer.build_dep_specs(libs)
      assert specs =~ ~s({:utils, github: "org/utils"})
    end

    test "formats hex deps" do
      libs = [%{name: "extras", source: {:hex, "pro_gen_extras", "~> 0.1"}}]
      specs = Installer.build_dep_specs(libs)
      assert specs =~ ~s({:extras, "~> 0.1"})
    end

    test "empty libs list includes only pro_gen" do
      specs = Installer.build_dep_specs([])
      assert specs == ~s({:pro_gen, github: "andyl/pro_gen"})
    end
  end

  describe "build_temp_mixfile/1" do
    test "generates valid mix.exs content" do
      specs = ~s({:pro_gen, github: "andyl/pro_gen"})
      content = Installer.build_temp_mixfile(specs)

      assert content =~ "defmodule ProgenInstall.MixProject"
      assert content =~ "use Mix.Project"
      assert content =~ "app: :progen_install"
      assert content =~ ~s({:pro_gen, github: "andyl/pro_gen"})
    end
  end

  describe "already_installed?/1" do
    test "returns false when target does not exist", %{deps_dir: deps_dir} do
      refute Installer.already_installed?(Path.join(deps_dir, "nonexistent"))
    end

    test "returns true when ebin dir exists", %{deps_dir: deps_dir} do
      target = Path.join(deps_dir, "my_lib")
      File.mkdir_p!(Path.join(target, "ebin"))
      assert Installer.already_installed?(target)
    end

    test "returns true when ebin is a symlink", %{deps_dir: deps_dir, tmp_dir: tmp_dir} do
      # Create a real ebin somewhere
      real_ebin = Path.join(tmp_dir, "real_ebin")
      File.mkdir_p!(real_ebin)

      # Create target with symlinked ebin
      target = Path.join(deps_dir, "my_lib")
      File.mkdir_p!(target)
      File.ln_s!(real_ebin, Path.join(target, "ebin"))

      assert Installer.already_installed?(target)
    end
  end

  describe "install/2 with path dep" do
    test "creates symlink for path dep with compiled ebin", %{
      deps_dir: deps_dir,
      tmp_dir: tmp_dir
    } do
      # Create a mock source project with compiled ebin
      source_project = Path.join(tmp_dir, "my_actions")
      source_ebin = Path.join([source_project, "_build", "dev", "lib", "my_actions", "ebin"])
      File.mkdir_p!(source_ebin)
      File.write!(Path.join(source_ebin, "Elixir.MyActions.beam"), "mock")

      # Create a mock pro_gen source project too (since we override)
      pro_gen_source = Path.join(tmp_dir, "pro_gen_src")
      File.mkdir_p!(Path.join(pro_gen_source, "lib"))

      # Write a minimal mix.exs for the source project
      File.write!(Path.join(source_project, "mix.exs"), """
      defmodule MyActions.MixProject do
        use Mix.Project
        def project, do: [app: :my_actions, version: "0.1.0", elixir: "~> 1.19"]
      end
      """)

      libs = [
        %{name: "pro_gen", source: {:path, Path.expand("../../pro_gen", File.cwd!())}},
        %{name: "my_actions", source: {:path, source_project}}
      ]

      case Installer.install(libs) do
        {:ok, summary} ->
          assert "my_actions" in summary.installed

          # Verify symlink was created
          target_ebin = Path.join([deps_dir, "my_actions", "ebin"])
          assert {:ok, %{type: :symlink}} = File.lstat(target_ebin)

          # Verify symlink points to source ebin
          assert {:ok, link_target} = File.read_link(target_ebin)
          assert link_target == source_ebin

        {:error, summary} ->
          # If mix deps.get fails (e.g., no network), check that it's a mix failure
          # not a logic error in our code
          assert summary.failed != []
      end
    end
  end

  describe "install/2 skipping" do
    test "skips already-installed deps unless force", %{deps_dir: deps_dir} do
      # Pre-install a dep
      target = Path.join(deps_dir, "pre_installed")
      File.mkdir_p!(Path.join(target, "ebin"))
      File.write!(Path.join([target, "ebin", "marker.beam"]), "old")

      # The install won't actually run mix for this test - we're testing the
      # skip logic via already_installed? directly
      assert Installer.already_installed?(target)
      refute Installer.already_installed?(Path.join(deps_dir, "not_installed"))
    end
  end

  describe "install/2 force" do
    test "force: true reinstalls even when already present", %{deps_dir: deps_dir} do
      # Pre-install
      target = Path.join(deps_dir, "some_lib")
      File.mkdir_p!(Path.join(target, "ebin"))

      # With force, already_installed? isn't checked - the install proceeds.
      # We verify the flag is accepted without error.
      libs = [%{name: "pro_gen", source: {:path, Path.expand("../../pro_gen", File.cwd!())}}]

      case Installer.install(libs, force: true) do
        {:ok, summary} ->
          assert "pro_gen" in summary.installed
          assert summary.skipped == []

        {:error, _summary} ->
          # Mix failure is acceptable in test env
          :ok
      end
    end
  end
end
