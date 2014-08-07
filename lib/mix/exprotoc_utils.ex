defmodule Exprotoc.MixUtils do
  def aliases(paths, files, prefix \\ nil) do
    [compile: [&lazy_exprotoc_build/1, "compile"]]
  end

  def lazy_exprotoc_build(_) do
    if File.dir? Mix.Tasks.Exprotoc.Build.get_output_dir do
      :ok
    else
      Mix.Task.run "exprotoc.build"
    end
  end
end
