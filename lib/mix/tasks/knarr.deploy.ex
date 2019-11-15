defmodule Mix.Tasks.Knarr.Deploy do
  use Mix.Task

  @shortdoc "Perform a configured release deployment"

  @impl Mix.Task
  def run(args) do
    try do
      Knarr.Deploy.run(args)
    rescue
      error in [RuntimeError] ->
        Mix.shell().error("knarr: #{error.message}")
    end
  end
end
