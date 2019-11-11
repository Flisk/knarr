defmodule Mix.Tasks.Deploy do
  use Mix.Task
  alias MixDeploy.Deploy

  @impl Mix.Task
  def run(args) do
    try do
      Deploy.run(args)
    rescue
      error in [RuntimeError] ->
        Mix.shell().error("mix_deploy: #{error.message}")
    end
  end
end
