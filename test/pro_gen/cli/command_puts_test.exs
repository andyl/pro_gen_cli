defmodule ProGen.CLI.CommandPutsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  describe "mix progen.command.run" do
    test "runs a shell command" do
      output =
        capture_io(fn ->
          Mix.Tasks.Progen.Command.Run.run(["test message", "echo hello"])
        end)

      assert output =~ "hello"
    end

    test "raises on command failure" do
      assert_raise Mix.Error, ~r/failed/, fn ->
        capture_io(fn ->
          Mix.Tasks.Progen.Command.Run.run(["msg", "false"])
        end)
      end
    end

    test "raises with no args" do
      assert_raise Mix.Error, ~r/Usage/, fn ->
        Mix.Tasks.Progen.Command.Run.run([])
      end
    end

    test "raises with only one arg" do
      assert_raise Mix.Error, ~r/Usage/, fn ->
        Mix.Tasks.Progen.Command.Run.run(["only message"])
      end
    end
  end

  describe "mix progen.puts" do
    test "prints formatted message" do
      output = capture_io(fn -> Mix.Tasks.Progen.Puts.run(["Hello CLI"]) end)
      assert output =~ "Hello CLI"
      assert output =~ ">"
    end

    test "raises with no args" do
      assert_raise Mix.Error, ~r/Usage/, fn ->
        Mix.Tasks.Progen.Puts.run([])
      end
    end
  end
end
