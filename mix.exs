defmodule ProGenCLI.MixProject do
  use Mix.Project

  @version "0.0.1"
  @source_url "https://github.com/andyl/pro_gen_cli"

  def project do
    [
      app: :pro_gen_cli,
      version: @version,
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "ProGen CLI",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    pro_gen_opts =
      if File.exists?("../pro_gen/mix.exs"),
        do: [path: "../pro_gen"],
        else: [github: "andyl/pro_gen"]

    [
      {:pro_gen, pro_gen_opts},
      {:yaml_elixir, "~> 2.11"},
      {:git_ops, "~> 2.9"},
      {:commit_hook, "~> 0.4"}
    ]
  end
end
