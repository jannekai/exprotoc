defmodule Exprotoc.MixUtils do
  def aliases(paths, files, prefix \\ nil) do
    prefix = if prefix == nil do
      []
    else
      ["--prefix " <> prefix]
    end
    augmented_cmd = Enum.join(["exprotoc.build"] ++ paths ++ Enum.map(files, &("--files " <> &1)) ++ prefix, " ")
    ['exprotoc.build': augmented_cmd,
     compile: [&conditional_exprotoc/1, "compile"]]
  end

  defp conditional_exprotoc(_) do
    if File.dir? Mix.Tasks.Exprotoc.Build.get_output_dir do
      :ok
    else
      Mix.Task.run "exprotoc.build"
    end
  end
end
