defmodule Mix.Tasks.Exprotoc.Build do
  use Mix.Task

  @shortdoc "Build .ex files for .proto files"

  @moduledoc """
  generate .ex files for proto messages into lib/exprotoc

  mix exprotoc.build [PATH ...] [--quiet] [--file FILE ...]

  directory of *.proto files at PATH is parsed and elixir modules are
  generated for FILE(s). exprotoc.clean is called before generating new
  modules.

  ## Command line options

    * `--file`   - file to generate .ex modules for
    * `--prefix` - optional prefix for .ex module definitions
  """
  def run(args) do
    IO.puts "=> Exprotoc Module Generation"
    Mix.Project.get! # Require the project to be available
    {opts, paths, _} = OptionParser.parse(args, switches: [file: :keep, prefix: :string])

    paths = case paths do
      [] ->
        priv_dir = Path.expand("priv")
        IO.puts "defaulting path to " <> Path.relative_to_cwd(priv_dir)
        if File.dir? priv_dir do
          [priv_dir]
        else
          Mix.raise "at lease one valid PATH must be specified!"
        end
      _ ->
        paths
    end

    files = case Keyword.get_values(opts, :file) do
      [] ->
        all = Enum.flat_map(paths, fn(p) -> Path.join(p, "**.proto") |> Path.wildcard end)
        IO.puts "defaulting files to " <> inspect(Enum.map(all, fn(f) -> Path.relative_to_cwd(f) end))
        all
      files ->
        files
    end

    prefix = Dict.get(opts, :prefix)

    Mix.Task.run "exprotoc.clean"
    run(files, paths, prefix)
  end

  def run(proto_files, proto_path, prefix) do
    proto_namespace = get_namespace(prefix)
    out_dir = get_output_dir
    File.mkdir_p out_dir
    Enum.each proto_files, fn(proto) ->
      IO.puts "Generating from " <> Path.relative_to_cwd(proto)
      Exprotoc.compile(proto, out_dir, proto_path, proto_namespace)
    end
  end

  def get_output_dir do
    Path.join(elixirc_path, "exprotoc")
  end

  def elixirc_path do
    project = Mix.Project.config
    project[:elixirc_paths] |> hd
  end

  defp get_namespace(nil) do
    nil
  end
  defp get_namespace(name) do
    String.to_atom(name)
  end
end
