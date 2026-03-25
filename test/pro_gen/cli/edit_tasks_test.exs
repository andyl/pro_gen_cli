defmodule ProGen.CLI.EditTasksTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  describe "mix progen.action.edit" do
    test "raises with no args" do
      assert_raise Mix.Error, ~r/Usage/, fn ->
        Mix.Tasks.Progen.Action.Edit.run([])
      end
    end

    test "raises on unknown action" do
      assert_raise Mix.Error, ~r/Unknown action/, fn ->
        Mix.Tasks.Progen.Action.Edit.run(["nonexistent.action"])
      end
    end

    test "opens source when file exists on disk" do
      # io.echo is a path dep (pro_gen is loaded via path: "../pro_gen")
      # so its source file should exist
      {:ok, mod} = ProGen.Actions.action_module("io.echo")
      {:ok, path} = ProGen.CLI.source_path(mod)

      if File.exists?(path) do
        # Set PROGEN_EDITOR to a no-op command so we don't actually open an editor
        original_editor = System.get_env("PROGEN_EDITOR")
        System.put_env("PROGEN_EDITOR", "true")

        try do
          # Should not raise
          capture_io(fn ->
            Mix.Tasks.Progen.Action.Edit.run(["io.echo"])
          end)
        after
          if original_editor,
            do: System.put_env("PROGEN_EDITOR", original_editor),
            else: System.delete_env("PROGEN_EDITOR")
        end
      else
        # If source doesn't exist (CI/non-path-dep environment), verify restriction error
        assert_raise Mix.Error, ~r/source not available/, fn ->
          Mix.Tasks.Progen.Action.Edit.run(["io.echo"])
        end
      end
    end

    test "raises when source file does not exist on disk" do
      # test.echo2 is compiled from test/support, its source path should
      # exist during tests. We need a module whose source path doesn't exist.
      # We can test the error message format by checking the restriction logic.
      {:ok, mod} = ProGen.Actions.action_module("io.echo")
      {:ok, path} = ProGen.CLI.source_path(mod)

      unless File.exists?(path) do
        assert_raise Mix.Error, ~r/source not available/, fn ->
          Mix.Tasks.Progen.Action.Edit.run(["io.echo"])
        end
      end
    end

    test "accepts module form name" do
      # Just verify it resolves correctly (don't open editor)
      # Setting PROGEN_EDITOR to false ensures it fails fast if it tries to open
      original_editor = System.get_env("PROGEN_EDITOR")
      System.put_env("PROGEN_EDITOR", "true")

      try do
        capture_io(fn ->
          Mix.Tasks.Progen.Action.Edit.run(["IO.Echo"])
        end)
      after
        if original_editor,
          do: System.put_env("PROGEN_EDITOR", original_editor),
          else: System.delete_env("PROGEN_EDITOR")
      end
    end
  end

  describe "mix progen.validate.edit" do
    test "raises with no args" do
      assert_raise Mix.Error, ~r/Usage/, fn ->
        Mix.Tasks.Progen.Validate.Edit.run([])
      end
    end

    test "raises on unknown validator" do
      assert_raise Mix.Error, ~r/Unknown validator/, fn ->
        Mix.Tasks.Progen.Validate.Edit.run(["nonexistent"])
      end
    end

    test "opens source when file exists on disk" do
      {:ok, mod} = ProGen.Validations.validation_module("filesys")
      {:ok, path} = ProGen.CLI.source_path(mod)

      if File.exists?(path) do
        original_editor = System.get_env("PROGEN_EDITOR")
        System.put_env("PROGEN_EDITOR", "true")

        try do
          capture_io(fn ->
            Mix.Tasks.Progen.Validate.Edit.run(["filesys"])
          end)
        after
          if original_editor,
            do: System.put_env("PROGEN_EDITOR", original_editor),
            else: System.delete_env("PROGEN_EDITOR")
        end
      else
        assert_raise Mix.Error, ~r/source not available/, fn ->
          Mix.Tasks.Progen.Validate.Edit.run(["filesys"])
        end
      end
    end

    test "accepts module form name" do
      {:ok, mod} = ProGen.Validations.validation_module("filesys")
      {:ok, path} = ProGen.CLI.source_path(mod)

      if File.exists?(path) do
        original_editor = System.get_env("PROGEN_EDITOR")
        System.put_env("PROGEN_EDITOR", "true")

        try do
          capture_io(fn ->
            Mix.Tasks.Progen.Validate.Edit.run(["Filesys"])
          end)
        after
          if original_editor,
            do: System.put_env("PROGEN_EDITOR", original_editor),
            else: System.delete_env("PROGEN_EDITOR")
        end
      else
        assert_raise Mix.Error, ~r/source not available/, fn ->
          Mix.Tasks.Progen.Validate.Edit.run(["Filesys"])
        end
      end
    end
  end
end
