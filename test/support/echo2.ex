defmodule ProGen.Action.Test.Echo2 do
  @moduledoc """
  Echo a message to stdout.
  """

  use ProGen.Action

  @impl true
  def opts_def do
    [message: [type: :string, required: true, doc: "The message to print"]]
  end

  @impl true
  def perform(args) do
    IO.puts("Test.Echo2")
    args |> Keyword.fetch!(:message) |> IO.puts()
    :ok
  end
end
