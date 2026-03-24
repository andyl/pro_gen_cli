defmodule ProGen.CLITest do
  use ExUnit.Case, async: true

  describe "resolve_name/1" do
    test "passes through lowercase string names" do
      assert ProGen.CLI.resolve_name("io.echo") == "io.echo"
    end

    test "passes through single-segment lowercase" do
      assert ProGen.CLI.resolve_name("filesys") == "filesys"
    end

    test "converts module form to string form" do
      assert ProGen.CLI.resolve_name("IO.Echo") == "io.echo"
    end

    test "converts multi-segment module form" do
      assert ProGen.CLI.resolve_name("Deps.Install") == "deps.install"
    end

    test "handles PascalCase segments with underscores" do
      assert ProGen.CLI.resolve_name("UsageRules.Setup") == "usage_rules.setup"
    end
  end

  describe "parse_kv_args/1" do
    test "parses simple key=value pairs" do
      assert ProGen.CLI.parse_kv_args(["project=my_app", "args=--no-ecto"]) ==
               [project: "my_app", args: "--no-ecto"]
    end

    test "handles value containing =" do
      assert ProGen.CLI.parse_kv_args(["args=--flag=val"]) == [args: "--flag=val"]
    end

    test "returns empty list for empty input" do
      assert ProGen.CLI.parse_kv_args([]) == []
    end

    test "raises on missing =" do
      assert_raise ArgumentError, ~r/expected key=value/, fn ->
        ProGen.CLI.parse_kv_args(["noequals"])
      end
    end
  end

  describe "parse_checks/1" do
    test "simple names become atoms" do
      assert ProGen.CLI.parse_checks(["has_mix", "has_git"]) == [:has_mix, :has_git]
    end

    test "parameterized checks become tuples" do
      assert ProGen.CLI.parse_checks(["has_file=mix.exs"]) == [{:has_file, "mix.exs"}]
    end

    test "mixed simple and parameterized" do
      assert ProGen.CLI.parse_checks(["has_mix", "has_file=mix.exs"]) ==
               [:has_mix, {:has_file, "mix.exs"}]
    end
  end

  describe "source_path/1" do
    test "returns path for a compiled module" do
      assert {:ok, path} = ProGen.CLI.source_path(ProGen.Action.IO.Echo)
      assert path =~ "lib/pro_gen/action/io/echo.ex"
    end
  end

  describe "format_table/1" do
    test "formats aligned columns" do
      rows = [{"short", "A description"}, {"much_longer_name", "Another"}]
      result = ProGen.CLI.format_table(rows)
      assert result =~ "short            "
      assert result =~ "much_longer_name"
    end

    test "returns empty string for empty list" do
      assert ProGen.CLI.format_table([]) == ""
    end
  end

  describe "format_list_json/1" do
    test "produces valid JSON array" do
      items = [{"io.echo", "Echo a message"}, {"git.commit", "Commit changes"}]
      json = ProGen.CLI.format_list_json(items)
      decoded = JSON.decode!(json)
      assert length(decoded) == 2
      assert hd(decoded)["name"] == "io.echo"
      assert hd(decoded)["description"] == "Echo a message"
    end

    test "handles empty list" do
      assert ProGen.CLI.format_list_json([]) == "[]"
    end
  end

  describe "format_list_text/1" do
    test "outputs one name per line" do
      items = [{"io.echo", "Echo"}, {"git.commit", "Commit"}]
      result = ProGen.CLI.format_list_text(items)
      assert result == "io.echo\ngit.commit"
    end
  end
end
