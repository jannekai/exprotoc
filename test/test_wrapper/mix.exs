defmodule TestWrapper.Mixfile do
  use Mix.Project

  def project do
    [ app: :test_wrapper,
      version: "0.0.1",
      elixir: ">= 0.12.5",
      deps: deps,
      aliases: aliases]
  end

  defp aliases do
    [compile: ["exprotoc.build --prefix Proto",
               "compile"],
     clean: ["clean",
             "exprotoc.clean"
            ]
    ]
  end

  # Returns the list of dependencies in the format:
  # { :foobar, git: "https://github.com/elixir-lang/foobar.git", tag: "0.1" }
  #
  # To specify particular versions, regardless of the tag, do:
  # { :barbat, "~> 0.1", github: "elixir-lang/barbat" }
  defp deps do
    [
     { :exprotoc, path: "../.." }
    ]
  end
end
