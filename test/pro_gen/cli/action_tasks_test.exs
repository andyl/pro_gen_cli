defmodule ProGen.CLI.ActionTasksTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  describe "mix progen.action.list" do
    test "table format lists actions with aligned columns" do
      output = capture_io(fn -> Mix.Tasks.Progen.Action.List.run([]) end)
      assert output =~ "io.echo"
      assert output =~ "Echo a message to stdout."
    end

    test "text format lists one name per line" do
      output = capture_io(fn -> Mix.Tasks.Progen.Action.List.run(["--format", "text"]) end)
      assert output =~ "io.echo\n"
      refute output =~ "Echo a message"
    end

    test "json format produces valid JSON" do
      output = capture_io(fn -> Mix.Tasks.Progen.Action.List.run(["--format", "json"]) end)
      decoded = JSON.decode!(String.trim(output))
      assert is_list(decoded)
      names = Enum.map(decoded, & &1["name"])
      assert "io.echo" in names
    end

    test "unknown format raises" do
      assert_raise Mix.Error, ~r/Unknown format/, fn ->
        Mix.Tasks.Progen.Action.List.run(["--format", "yaml"])
      end
    end
  end

  describe "mix progen.action.info" do
    test "displays action metadata by string name" do
      output = capture_io(fn -> Mix.Tasks.Progen.Action.Info.run(["io.echo"]) end)
      assert output =~ "Module:"
      assert output =~ "ProGen.Action.IO.Echo"
      assert output =~ "io.echo"
      assert output =~ "message"
    end

    test "accepts module form name" do
      output = capture_io(fn -> Mix.Tasks.Progen.Action.Info.run(["IO.Echo"]) end)
      assert output =~ "ProGen.Action.IO.Echo"
    end

    test "raises on unknown action" do
      assert_raise Mix.Error, fn ->
        Mix.Tasks.Progen.Action.Info.run(["nonexistent.action"])
      end
    end

    test "raises with no args" do
      assert_raise Mix.Error, ~r/Usage/, fn ->
        Mix.Tasks.Progen.Action.Info.run([])
      end
    end
  end

  describe "mix progen.action.run" do
    test "runs action with key=value args" do
      output =
        capture_io(fn ->
          Mix.Tasks.Progen.Action.Run.run(["msg", "test.echo2", "message=hello"])
        end)

      assert output =~ "hello"
    end

    test "raises on unknown action" do
      assert_raise Mix.Error, fn ->
        capture_io(fn ->
          Mix.Tasks.Progen.Action.Run.run(["msg", "nonexistent.action"])
        end)
      end
    end

    test "raises on missing required arg and shows usage" do
      assert_raise Mix.Error, ~r/message/, fn ->
        capture_io(fn ->
          Mix.Tasks.Progen.Action.Run.run(["msg", "test.echo2"])
        end)
      end
    end

    test "raises with no args" do
      assert_raise Mix.Error, ~r/Usage/, fn ->
        Mix.Tasks.Progen.Action.Run.run([])
      end
    end
  end

  describe "mix progen.action.cat" do
    test "prints source code of an action" do
      output = capture_io(fn -> Mix.Tasks.Progen.Action.Cat.run(["io.echo"]) end)
      assert output =~ "defmodule ProGen.Action.IO.Echo"
      assert output =~ "def perform"
    end

    test "accepts module form name" do
      output = capture_io(fn -> Mix.Tasks.Progen.Action.Cat.run(["IO.Echo"]) end)
      assert output =~ "defmodule ProGen.Action.IO.Echo"
    end

    test "raises on unknown action" do
      assert_raise Mix.Error, ~r/Unknown action/, fn ->
        Mix.Tasks.Progen.Action.Cat.run(["nonexistent.action"])
      end
    end

    test "raises with no args" do
      assert_raise Mix.Error, ~r/Usage/, fn ->
        Mix.Tasks.Progen.Action.Cat.run([])
      end
    end
  end
end
