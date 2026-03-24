defmodule ProGen.CLI.AutoCommitTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  setup do
    Application.put_env(:pro_gen, :auto_commit, true)

    original_dir = File.cwd!()

    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "pro_gen_test_cli_auto_commit_#{:erlang.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)
    File.cd!(tmp_dir)

    System.cmd("git", ["init"])
    System.cmd("git", ["config", "user.email", "test@test.com"])
    System.cmd("git", ["config", "user.name", "Test"])

    File.write!(".gitkeep", "")
    System.cmd("git", ["add", "."])
    System.cmd("git", ["commit", "-m", "initial"])

    on_exit(fn ->
      Application.put_env(:pro_gen, :auto_commit, false)
      File.cd!(original_dir)
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  describe "action.run auto-commit" do
    test "creates a commit after successful action" do
      File.write!("cli_test.txt", "test content")

      capture_io(fn ->
        Mix.Tasks.Progen.Action.Run.run(["Echo test", "io.echo", "message=hello"])
      end)

      {log, 0} = System.cmd("git", ["log", "--format=%s"])
      assert log =~ "[ProGen] Echo test"
    end

    test "commit=false suppresses auto-commit" do
      File.write!("cli_test2.txt", "test content")

      capture_io(fn ->
        Mix.Tasks.Progen.Action.Run.run([
          "Echo test",
          "io.echo",
          "message=hello",
          "commit=false"
        ])
      end)

      {log, 0} = System.cmd("git", ["log", "--format=%s"])
      refute log =~ "[ProGen] Echo test"
    end
  end

  describe "command.run auto-commit" do
    test "creates a commit after successful command" do
      capture_io(fn ->
        Mix.Tasks.Progen.Command.Run.run(["Create file", "touch cmdtest.txt"])
      end)

      {log, 0} = System.cmd("git", ["log", "--format=%s"])
      assert log =~ "[ProGen] Create file"
    end
  end

  describe "conventional commits via CLI" do
    test "CC enabled formats commit message with type" do
      File.write!(".progen.yml", "use_conventional_commits: true\n")
      File.write!("cc_cli_test.txt", "content")

      capture_io(fn ->
        Mix.Tasks.Progen.Action.Run.run(["Add feature", "io.echo", "message=hello"])
      end)

      {log, 0} = System.cmd("git", ["log", "--format=%s", "-1"])
      assert String.trim(log) == "chore(action): [ProGen] Add feature"
    end

    test "CC disabled preserves legacy format" do
      File.write!("cc_cli_test2.txt", "content")

      capture_io(fn ->
        Mix.Tasks.Progen.Action.Run.run(["Echo test", "io.echo", "message=hello"])
      end)

      {log, 0} = System.cmd("git", ["log", "--format=%s", "-1"])
      assert String.trim(log) == "[ProGen] Echo test"
    end
  end
end
