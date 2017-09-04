defmodule PotatoIrcServer.Mixfile do
  use Mix.Project

  def project do
    [app: :potato_irc_server,
     version: "0.1.0",
     elixir: "~> 1.6-dev",
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:logger]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:exirc, "~> 1.0.1"}]
  end
end
