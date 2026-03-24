defmodule Mix.Tasks.Progen.Validate.List do
  @shortdoc "List all registered ProGen validators"

  @moduledoc """
  Lists all registered ProGen validators.

  ```bash
  mix progen.validate.list [--format <fmt>]
  ```

  ## Formats

    * `table` (default) — aligned columns with name and description
    * `text` — one validator name per line
    * `json` — JSON array of `{"name", "description"}` objects
  """

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest} = OptionParser.parse!(args, strict: [format: :string])
    format = Keyword.get(opts, :format, "table")

    items = ProGen.Validations.list_validations()

    output =
      case format do
        "table" -> ProGen.CLI.format_table(items)
        "text" -> ProGen.CLI.format_list_text(items)
        "json" -> ProGen.CLI.format_list_json(items)
        other -> Mix.raise("Unknown format: #{inspect(other)}. Use table, text, or json.")
      end

    if output != "", do: Mix.shell().info(output)
  end
end
