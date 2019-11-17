defmodule Mix.Tasks.Knarr.Deploy do
  use Mix.Task

  @rescue_errors [
    Knarr.UsageError,
    Knarr.RemoteDirsError,
    Knarr.LockFileError
  ]

  @shortdoc "Perform a configured release deployment"

  @impl Mix.Task
  def run(args) do
    try do
      Knarr.Deploy.run(args)
    rescue
      error in @rescue_errors ->
        Mix.shell().error("\nknarr: #{error.message}")
        exit({:shutdown, 1})

      error in Knarr.RemoteCommandError ->
        Mix.shell().error("""

        knarr: #{error.message}

        The fact that you're seeing this error is a bug; it means a
        proper error message for this failure mode is missing. A quick
        bug report would be much appreciated.
        """
        )
    end
  end
end
