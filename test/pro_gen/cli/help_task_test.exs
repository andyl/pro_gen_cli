defmodule ProGen.CLI.HelpTaskTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  describe "mix progen" do
    test "lists known progen tasks" do
      output = capture_io(fn -> Mix.Tasks.Progen.run([]) end)

      assert output =~ "ProGen — available tasks:"
      assert output =~ "progen.action.list"
      assert output =~ "progen.install"
      assert output =~ "progen.puts"
      assert output =~ "progen.validate.list"
      assert output =~ "progen.command.run"
    end

    test "includes shortdoc descriptions" do
      output = capture_io(fn -> Mix.Tasks.Progen.run([]) end)

      assert output =~ "List all registered ProGen actions"
      assert output =~ "Print a formatted ProGen message"
    end

    test "does not include itself in the listing" do
      output = capture_io(fn -> Mix.Tasks.Progen.run([]) end)

      refute output =~ "mix progen " <> " "
      # The task name "progen" without a dot suffix should not appear as a listed task.
      # All listed tasks start with "progen." (have a dot after progen)
      lines = String.split(output, "\n")

      task_lines =
        Enum.filter(lines, fn line ->
          String.contains?(line, "  mix progen")
        end)

      Enum.each(task_lines, fn line ->
        assert line =~ "mix progen."
      end)
    end

    test "tasks are sorted alphabetically within groups" do
      output = capture_io(fn -> Mix.Tasks.Progen.run([]) end)

      # Split output into groups (separated by blank lines) and check each group
      groups =
        output
        |> String.split("\n\n")
        |> Enum.flat_map(fn section ->
          names =
            section
            |> String.split("\n")
            |> Enum.filter(&String.contains?(&1, "  mix progen."))
            |> Enum.map(fn line ->
              line |> String.trim() |> String.split(" ") |> Enum.at(1)
            end)

          if names == [], do: [], else: [names]
        end)

      Enum.each(groups, fn names ->
        assert names == Enum.sort(names)
      end)
    end

    test "groups are separated by blank lines" do
      output = capture_io(fn -> Mix.Tasks.Progen.run([]) end)

      # Action and validate groups should be separated
      assert output =~ "progen.action."
      assert output =~ "progen.validate."
      assert output =~ "\n\n"
    end
  end
end
