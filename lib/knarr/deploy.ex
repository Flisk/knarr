defmodule Knarr.Deploy do
  alias Knarr.Console
  alias Knarr.Tasks

  def run(args) do
    state_connected =
      args
      |> initialize()
      |> Tasks.Local.build_release()
      |> Tasks.Remote.connect()

    try do
      state_connected
      |> Tasks.Remote.create_release_dir()
      |> Tasks.Local.rsync_release()
      |> Tasks.Remote.symlink_shared_paths()
      |> Tasks.Remote.update_current_symlink()
      |> Tasks.Remote.run_hooks()
      |> Tasks.Remote.clean_releases()
      |> report_success()
    after
      Tasks.Remote.disconnect(state_connected)
    end

    nil
  end

  defp initialize(args) do
    case args do
      [] ->
        raise Knarr.UsageError, "missing deployment config argument"

      [config_name] ->
        %{
          config: Knarr.Config.load(config_name),
          build_dir: "_build/knarr"
        }

      _ ->
        raise Knarr.UsageError, "too many arguments"
    end
  end

  defp report_success(%{remote_release_dir: release_dir}) do
    Console.success("Release #{release_dir} deployed successfully!")
  end
end
