defmodule Mix.Tasks.Progen.Puts do
  @shortdoc "Print a formatted ProGen message"

  @moduledoc """
  Prints a formatted message using `ProGen.Script.puts/1`.

  ```bash
  mix progen.puts "message"
  ```
  """

  use Mix.Task

  @impl true
  def run(args) do
    case args do
      [message | _] ->
        ProGen.Script.puts(message)

      [] ->
        Mix.raise("Usage: mix progen.puts \"message\"")
    end
  end
end
