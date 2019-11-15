defmodule Mix.Tasks.Deploy do
  use Mix.Task

  alias Knarr.Deploy

  @impl Mix.Task
  def run(args) do
    try do
      Deploy.run(args)
    rescue
      error in [RuntimeError] ->
        Mix.shell().error("knarr: #{error.message}")
    end
  end
end
