defmodule Mix.Tasks.Exprotoc.Build do
  use Mix.Task

  @shortdoc "Build .ex files for .proto files"
  @recursive true

  @moduledoc """
  generate .ex files for proto messages into lib/exprotoc

  mix exprotoc.build [PATH ...] [--quiet] [--file FILE ...]

  directory of *.proto files at PATH is parsed and elixir modules are
  generated for FILE(s). exprotoc.clean is called before generating new
  modules.

  ## Command line options

    * `--file`     - file to generate .ex modules for
    * `--prefix`   - optional prefix for .ex module definitions
    * `--no-clean` - do not remove existing .ex modules before generation
  """
  def default_paths do
    priv_dir = Path.expand("priv")
    if File.dir? priv_dir do
      [priv_dir]
    else
      []
    end
  end

  def default_files(paths) do
    Enum.flat_map(paths, fn(p) -> Path.join(p, "**.proto") |> Path.wildcard end)
  end

  def default_prefix() do
    nil
  end

  def run(args) do
    config = Mix.Project.config
    exprotoc_config = Dict.get(config, :exprotoc, %{})

    Mix.Project.get! # Require the project to be available
    IO.puts "==> Exprotoc Module Generation: " <> to_string(Mix.Project.config[:app])
    {override_opts, override_paths, _} = OptionParser.parse(args, switches: [file: :keep, prefix: :string, clean: :boolean])

    clean = Dict.get(override_opts, :clean, true)
    paths = Enum.find([override_paths, exprotoc_config[:paths]],
                      default_paths(),
                      fn(x) -> x != nil && x != [] end)

    files = Enum.find([Keyword.get_values(override_opts, :file), exprotoc_config[:files]],
                      default_files(paths),
                      fn(x) -> x != nil && x != [] end)

    prefix = Enum.find([Dict.get(override_opts, :prefix), exprotoc_config[:prefix]],
                       default_prefix(),
                       fn(x) -> x != nil end)
    if clean do
      Mix.Task.run "exprotoc.clean"
    end
    run(files, paths, prefix)
  end

  def run([], proto_path, prefix) do
    :ok
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
