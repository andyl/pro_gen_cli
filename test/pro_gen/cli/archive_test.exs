defmodule ProGen.CLI.ArchiveTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  @tag :slow
  @tag timeout: 60_000
  test "archive.build produces .ez with only CLI modules", %{tmp_dir: tmp_dir} do
    project_dir = Path.expand("../../..", __DIR__) |> Path.expand()
    ez_name = "pro_gen_cli-0.0.1.ez"

    {_output, 0} =
      System.cmd("mix", ["archive.build", "--output", Path.join(tmp_dir, ez_name)],
        cd: project_dir,
        stderr_to_stdout: true
      )

    ez_path = Path.join(tmp_dir, ez_name)
    assert File.exists?(ez_path)

    # List entries in the .ez zip
    {:ok, entries} = :zip.list_dir(~c"#{ez_path}")

    beam_names =
      for {:zip_file, name, _, _, _, _} <- entries,
          name = to_string(name),
          String.ends_with?(name, ".beam") do
        Path.basename(name, ".beam")
      end

    # Must include CLI modules
    assert "Elixir.ProGen.CLI" in beam_names
    assert "Elixir.ProGen.CLI.Bootstrap" in beam_names
    assert "Elixir.ProGen.CLI.GlobalConfig" in beam_names
    assert "Elixir.ProGen.CLI.Installer" in beam_names
    assert "Elixir.Mix.Tasks.Progen.Install" in beam_names
    assert "Elixir.Mix.Tasks.Progen.Action.List" in beam_names

    # Must NOT include pro_gen core modules (actions, validations)
    refute Enum.any?(beam_names, &String.starts_with?(&1, "Elixir.ProGen.Action."))
    refute Enum.any?(beam_names, &String.starts_with?(&1, "Elixir.ProGen.Validate."))
    refute Enum.any?(beam_names, &String.starts_with?(&1, "Elixir.ProGen.Actions"))
    refute Enum.any?(beam_names, &String.starts_with?(&1, "Elixir.ProGen.Script"))

    # Must NOT include dependency modules
    refute Enum.any?(beam_names, &String.starts_with?(&1, "Elixir.YamlElixir"))
    refute Enum.any?(beam_names, &String.contains?(&1, "yamerl"))
  end
end
