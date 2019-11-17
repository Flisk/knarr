defmodule Knarr.Tasks.Remote do
  @moduledoc """
  Deployment tasks that run on the remote system.
  """

  import Knarr.Console, only: [info: 1]
  
  alias Knarr.Remote

  @spec connect(map) :: map
  def connect(%{config: config} = state) do
    remote = Remote.connect(config.host, config.port, config.user, config.app_path)
    Map.put(state, :remote, remote)
  end

  @spec create_release_dir(map) :: map
  def create_release_dir(%{remote: remote, config: config} = state) do
    next_release = Remote.next_release(remote)
    {_id, release_dir} = next_release

    remote = Remote.create_release_dir(
      remote, next_release, reflink: config.rsync_copy_reflink
    )

    state
    |> Map.put(:remote, remote)
    |> Map.put(:remote_release_dir, release_dir)
  end

  @spec symlink_shared_paths(map) :: map
  def symlink_shared_paths(
    %{
      remote: remote,
      config: config,
      remote_release_dir: release_dir
    } = state
  ) do
    info("remote: linking shared paths")

    Remote.symlink_shared_paths(remote, release_dir, config.shared_files)
    Remote.symlink_shared_paths(remote, release_dir, config.shared_directories)

    state
  end

  @spec update_current_symlink(map) :: map
  def update_current_symlink(
    %{
      remote: remote,
      remote_release_dir: release_dir
    } = state
  ) do
    info("remote: updating current symlink")
    Remote.symlink_current(remote, release_dir)
    state
  end

  @spec run_hooks(map) :: map
  def run_hooks(%{remote: remote, config: config} = state) do
    info("remote: running after_deploy hooks")
    Remote.run_commands(remote, config.hooks_after_deploy)
    state
  end

  @spec clean_releases(map) :: map
  def clean_releases(
    %{
      remote: remote,
      config: config
    } = state
  ) do
    deleted = Remote.clean_releases(remote, config.max_releases)

    case Enum.empty?(deleted) do
      true -> info("remote: no old releases deleted")

      false ->
        deleted =
          deleted
          |> Stream.map(fn {_id, dir} -> dir end)
          |> Enum.join(", ")

        info("remote: old releases deleted: #{deleted}")
    end

    state
  end
end
