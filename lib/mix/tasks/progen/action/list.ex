defmodule Mix.Tasks.Progen.Action.List do
  @shortdoc "List all registered ProGen actions"

  @moduledoc """
  Lists all registered ProGen actions.

  ```bash
  mix progen.action.list [--format <fmt>]
  ```

  ## Formats

    * `table` (default) — aligned columns with name and description
    * `text` — one action name per line
    * `json` — JSON array of `{"name", "description"}` objects
  """

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest} = OptionParser.parse!(args, strict: [format: :string])
    format = Keyword.get(opts, :format, "table")

    items = ProGen.Actions.list_actions()

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
