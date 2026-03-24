defmodule ProGen.CLI.ValidateTasksTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  describe "mix progen.validate.list" do
    test "table format lists validators" do
      output = capture_io(fn -> Mix.Tasks.Progen.Validate.List.run([]) end)
      assert output =~ "filesys"
    end

    test "text format lists one per line" do
      output = capture_io(fn -> Mix.Tasks.Progen.Validate.List.run(["--format", "text"]) end)
      lines = String.split(String.trim(output), "\n")
      assert "filesys" in lines
    end

    test "json format produces valid JSON" do
      output = capture_io(fn -> Mix.Tasks.Progen.Validate.List.run(["--format", "json"]) end)
      decoded = JSON.decode!(String.trim(output))
      assert is_list(decoded)
      names = Enum.map(decoded, & &1["name"])
      assert "filesys" in names
    end
  end

  describe "mix progen.validate.info" do
    test "displays validator metadata" do
      output = capture_io(fn -> Mix.Tasks.Progen.Validate.Info.run(["filesys"]) end)
      assert output =~ "Module:"
      assert output =~ "ProGen.Validate.Filesys"
      assert output =~ "Checks:"
    end

    test "accepts module form name" do
      output = capture_io(fn -> Mix.Tasks.Progen.Validate.Info.run(["Filesys"]) end)
      assert output =~ "ProGen.Validate.Filesys"
    end

    test "raises on unknown validator" do
      assert_raise Mix.Error, fn ->
        Mix.Tasks.Progen.Validate.Info.run(["nonexistent"])
      end
    end

    test "raises with no args" do
      assert_raise Mix.Error, ~r/Usage/, fn ->
        Mix.Tasks.Progen.Validate.Info.run([])
      end
    end
  end

  describe "mix progen.validate.run" do
    test "runs simple checks" do
      output =
        capture_io(fn ->
          Mix.Tasks.Progen.Validate.Run.run(["filesys", "has_mix"])
        end)

      assert output =~ "passed"
    end

    test "runs parameterized check" do
      output =
        capture_io(fn ->
          Mix.Tasks.Progen.Validate.Run.run(["filesys", "has_file=mix.exs"])
        end)

      assert output =~ "passed"
    end

    test "raises on failed check" do
      assert_raise Mix.Error, fn ->
        capture_io(fn ->
          Mix.Tasks.Progen.Validate.Run.run(["filesys", "has_file=nonexistent_xyz.txt"])
        end)
      end
    end

    test "raises with no checks" do
      assert_raise Mix.Error, ~r/Usage/, fn ->
        Mix.Tasks.Progen.Validate.Run.run(["filesys"])
      end
    end
  end

  describe "mix progen.validate.cat" do
    test "prints source code of a validator" do
      output = capture_io(fn -> Mix.Tasks.Progen.Validate.Cat.run(["filesys"]) end)
      assert output =~ "defmodule ProGen.Validate.Filesys"
    end

    test "raises on unknown validator" do
      assert_raise Mix.Error, ~r/Unknown validator/, fn ->
        Mix.Tasks.Progen.Validate.Cat.run(["nonexistent"])
      end
    end
  end
end
