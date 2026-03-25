defmodule ProGen.CLI.GlobalConfigTest do
  use ExUnit.Case, async: false

  alias ProGen.CLI.GlobalConfig

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    config_dir = Path.join(tmp_dir, "pro_gen")
    File.mkdir_p!(config_dir)
    Application.put_env(:pro_gen_cli, :config_dir, config_dir)

    on_exit(fn ->
      Application.delete_env(:pro_gen_cli, :config_dir)
    end)

    %{config_dir: config_dir}
  end

  describe "config_dir/0" do
    test "returns the overridden config dir", %{config_dir: config_dir} do
      assert GlobalConfig.config_dir() == config_dir
    end

    test "defaults to ~/.config/pro_gen when not overridden" do
      Application.delete_env(:pro_gen_cli, :config_dir)
      assert GlobalConfig.config_dir() == Path.expand("~/.config/pro_gen")
    end
  end

  describe "deps_dir/0" do
    test "returns config_dir/deps", %{config_dir: config_dir} do
      assert GlobalConfig.deps_dir() == Path.join(config_dir, "deps")
    end
  end

  describe "config_path/0" do
    test "returns nil when no config file exists" do
      assert GlobalConfig.config_path() == nil
    end

    test "finds .yml file", %{config_dir: config_dir} do
      yml = Path.join(config_dir, "config.yml")
      File.write!(yml, "libs: []\n")
      assert GlobalConfig.config_path() == yml
    end

    test "finds .yaml file", %{config_dir: config_dir} do
      yaml = Path.join(config_dir, "config.yaml")
      File.write!(yaml, "libs: []\n")
      assert GlobalConfig.config_path() == yaml
    end

    test "prefers .yml over .yaml", %{config_dir: config_dir} do
      yml = Path.join(config_dir, "config.yml")
      yaml = Path.join(config_dir, "config.yaml")
      File.write!(yml, "libs: []\n")
      File.write!(yaml, "libs: []\n")
      assert GlobalConfig.config_path() == yml
    end
  end

  describe "read/0" do
    test "returns empty libs when no config file exists" do
      assert GlobalConfig.read() == {:ok, %{libs: []}}
    end

    test "parses valid YAML with libs", %{config_dir: config_dir} do
      yaml = """
      libs:
        - name: my_actions
          path: /home/user/src/my_actions
        - name: team_utils
          github: myorg/pro_gen_utils
      """

      File.write!(Path.join(config_dir, "config.yml"), yaml)

      assert {:ok, %{libs: libs}} = GlobalConfig.read()
      assert length(libs) == 2
      assert Enum.at(libs, 0)["name"] == "my_actions"
      assert Enum.at(libs, 1)["github"] == "myorg/pro_gen_utils"
    end

    test "returns empty libs for empty file", %{config_dir: config_dir} do
      File.write!(Path.join(config_dir, "config.yml"), "")
      assert GlobalConfig.read() == {:ok, %{libs: []}}
    end

    test "returns empty libs when libs key is absent", %{config_dir: config_dir} do
      File.write!(Path.join(config_dir, "config.yml"), "some_other_key: true\n")
      assert {:ok, %{libs: []}} = GlobalConfig.read()
    end

    test "returns error for malformed YAML", %{config_dir: config_dir} do
      File.write!(Path.join(config_dir, "config.yml"), ":\ninvalid: [yaml\n")
      assert {:error, msg} = GlobalConfig.read()
      assert msg =~ "Failed to parse"
    end

    test "returns error for non-map YAML", %{config_dir: config_dir} do
      File.write!(Path.join(config_dir, "config.yml"), "- just\n- a list\n")
      assert {:error, msg} = GlobalConfig.read()
      assert msg =~ "must contain a YAML mapping"
    end
  end

  describe "validate/1" do
    test "validates path source" do
      config = %{libs: [%{"name" => "my_lib", "path" => "/home/user/my_lib"}]}

      assert {:ok, [%{name: "my_lib", source: {:path, "/home/user/my_lib"}}]} =
               GlobalConfig.validate(config)
    end

    test "validates github source" do
      config = %{libs: [%{"name" => "team_utils", "github" => "myorg/utils"}]}

      assert {:ok, [%{name: "team_utils", source: {:github, "myorg/utils"}}]} =
               GlobalConfig.validate(config)
    end

    test "validates hex source with version" do
      config = %{
        libs: [%{"name" => "community", "hex" => "pro_gen_community", "version" => "~> 0.2"}]
      }

      assert {:ok, [%{name: "community", source: {:hex, "pro_gen_community", "~> 0.2"}}]} =
               GlobalConfig.validate(config)
    end

    test "validates multiple libs of different types" do
      config = %{
        libs: [
          %{"name" => "local", "path" => "/tmp/local"},
          %{"name" => "remote", "github" => "org/repo"},
          %{"name" => "hexed", "hex" => "some_pkg", "version" => "~> 1.0"}
        ]
      }

      assert {:ok, libs} = GlobalConfig.validate(config)
      assert length(libs) == 3
      assert Enum.at(libs, 0).source == {:path, "/tmp/local"}
      assert Enum.at(libs, 1).source == {:github, "org/repo"}
      assert Enum.at(libs, 2).source == {:hex, "some_pkg", "~> 1.0"}
    end

    test "returns ok with empty list when libs is empty" do
      assert {:ok, []} = GlobalConfig.validate(%{libs: []})
    end

    test "returns ok with empty list when libs key is absent" do
      assert {:ok, []} = GlobalConfig.validate(%{})
    end

    test "errors when name is missing" do
      config = %{libs: [%{"path" => "/tmp/foo"}]}
      assert {:error, msg} = GlobalConfig.validate(config)
      assert msg =~ "missing required \"name\""
    end

    test "errors when name is not a string" do
      config = %{libs: [%{"name" => 123, "path" => "/tmp/foo"}]}
      assert {:error, msg} = GlobalConfig.validate(config)
      assert msg =~ "\"name\" must be a string"
    end

    test "errors when no source key is present" do
      config = %{libs: [%{"name" => "orphan"}]}
      assert {:error, msg} = GlobalConfig.validate(config)
      assert msg =~ "must have exactly one source"
    end

    test "errors when multiple source keys are present" do
      config = %{libs: [%{"name" => "confused", "path" => "/tmp", "github" => "org/repo"}]}
      assert {:error, msg} = GlobalConfig.validate(config)
      assert msg =~ "must have exactly one source"
      assert msg =~ "path"
      assert msg =~ "github"
    end

    test "errors when hex dep is missing version" do
      config = %{libs: [%{"name" => "no_ver", "hex" => "some_pkg"}]}
      assert {:error, msg} = GlobalConfig.validate(config)
      assert msg =~ "hex deps require a \"version\" field"
    end

    test "errors when version is not a string" do
      config = %{libs: [%{"name" => "bad_ver", "hex" => "pkg", "version" => 1.0}]}
      assert {:error, msg} = GlobalConfig.validate(config)
      assert msg =~ "\"version\" must be a string"
    end

    test "errors when libs is not a list" do
      config = %{libs: "not a list"}
      assert {:error, msg} = GlobalConfig.validate(config)
      assert msg =~ "\"libs\" must be a list"
    end

    test "errors when lib entry is not a map" do
      config = %{libs: ["just a string"]}
      assert {:error, msg} = GlobalConfig.validate(config)
      assert msg =~ "each entry must be a map"
    end

    test "collects multiple errors" do
      config = %{
        libs: [
          %{"path" => "/tmp/foo"},
          %{"name" => "no_source"}
        ]
      }

      assert {:error, msg} = GlobalConfig.validate(config)
      assert msg =~ "missing required \"name\""
      assert msg =~ "must have exactly one source"
    end
  end

  describe "read/0 + validate/1 integration" do
    test "full round-trip with valid config", %{config_dir: config_dir} do
      yaml = """
      libs:
        - name: pro_gen
          path: /home/user/src/pro_gen
        - name: team_pack
          github: myorg/team_pack
        - name: extras
          hex: pro_gen_extras
          version: "~> 0.1"
      """

      File.write!(Path.join(config_dir, "config.yml"), yaml)

      assert {:ok, config} = GlobalConfig.read()
      assert {:ok, libs} = GlobalConfig.validate(config)
      assert length(libs) == 3

      assert %{name: "pro_gen", source: {:path, "/home/user/src/pro_gen"}} = Enum.at(libs, 0)
      assert %{name: "team_pack", source: {:github, "myorg/team_pack"}} = Enum.at(libs, 1)
      assert %{name: "extras", source: {:hex, "pro_gen_extras", "~> 0.1"}} = Enum.at(libs, 2)
    end

    test "round-trip with no config file" do
      assert {:ok, config} = GlobalConfig.read()
      assert {:ok, []} = GlobalConfig.validate(config)
    end
  end
end
