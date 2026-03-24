defmodule Mix.Tasks.Progen.Validate.Run do
  @shortdoc "Run a ProGen validator with specified checks"

  @moduledoc """
  Runs a named ProGen validator with the specified checks.

  ```bash
  mix progen.validate.run <validator> <check> [<check> ...]
  ```

  Simple check names (e.g., `has_mix`) become atoms. Parameterized checks
  use key=value form (e.g., `has_file=mix.exs` becomes `{:has_file, "mix.exs"}`).

  Accepts both string form (`filesys`) and module form (`Filesys`).
  """

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [ref | check_args] when check_args != [] ->
        name = ProGen.CLI.resolve_name(ref)
        checks = ProGen.CLI.parse_checks(check_args)

        case ProGen.Validations.run(name, checks: checks) do
          :ok ->
            Mix.shell().info("Validation passed.")

          {:error, msg} ->
            Mix.raise(msg)
        end

      _ ->
        Mix.raise("Usage: mix progen.validate.run <validator> <check> [<check> ...]")
    end
  end
end
