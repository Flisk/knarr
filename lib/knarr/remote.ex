defmodule Knarr.Remote do
  @moduledoc """
  This module represents a connection to a remote host and
  encapsulates all direct interaction with it.
  """

  import Knarr.Console, only: [info: 1]

  alias Knarr.SSH

  defstruct [:ssh, :app_path, :lock_path, :releases]

  @type t                  :: %__MODULE__{}
  @type release_tuple      :: {pos_integer, String.t}
  @type release_tuple_list :: [release_tuple]

  @lock_file    ".knarr-lock"
  @current_dir  "current"
  @releases_dir "releases"
  @shared_dir   "shared"

  @spec connect(String.t, pos_integer, String.t, String.t) :: t
  def connect(host, port, user, app_path) do
    info("connecting to #{host}:#{port} as #{user}")

    ssh = SSH.connect(host, port, user)
    check_deploy_dirs(ssh, app_path)

    lock_path = Path.join(app_path, @lock_file)
    create_lock_file(ssh, lock_path)

    releases = find_releases(ssh, app_path)

    %__MODULE__{
      ssh: ssh,
      app_path: app_path,
      lock_path: lock_path,
      releases: releases
    }
  end

  @spec disconnect(t) :: nil
  def disconnect(remote), do: delete_lock_file(remote.ssh, remote.lock_path)

  @spec check_deploy_dirs(port, String.t) :: nil
  defp check_deploy_dirs(ssh, app_path) do
    try do
      SSH.run!(ssh, "cd " <> app_path)
      SSH.run!(ssh, "test -d " <> @releases_dir)
      SSH.run!(ssh, "test -d " <> @shared_dir)
      SSH.run!(ssh, "cd")
    rescue
      Knarr.RemoteCommandError ->
        raise Knarr.RemoteDirsError, app_path: app_path
    end

    nil
  end

  @spec find_releases(port, String.t) :: release_tuple_list
  defp find_releases(ssh, app_path) do
    releases_path = Path.join(app_path, @releases_dir)
    SSH.run!(ssh, "cd " <> releases_path)

    find_output = SSH.run!(ssh, "find . -path './*' -prune -type d")

    SSH.run!(ssh, "cd")

    find_output
    |> Stream.map(&parse_release_dir(&1, app_path))
    |> Enum.sort()
    |> Enum.reverse()
  end

  @spec parse_release_dir(String.t, String.t) :: release_tuple
  defp parse_release_dir(dir, app_path) do
    basename    = Path.basename(dir)
    release_dir = Path.join([app_path, @releases_dir, basename])

    case Integer.parse(basename) do
      {release_number, ""} -> {release_number, release_dir}
      _ -> raise "invalid release directory: #{release_dir}"
    end
  end

  @spec create_lock_file(port, String.t) :: nil
  defp create_lock_file(ssh, lock_path) do
    {:ok, hostname} = :inet.gethostname()
    time = DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string()

    lock_text = "#{hostname}\n#{time}\n" |> Base.encode64()

    # set -C enables "noclobber", which prevents shell redirection
    # from overwriting existing files
    command = "set -C && echo #{lock_text} > #{lock_path} && set +C"

    case SSH.run(ssh, command) do
      {0, []} ->
        nil

      {_non_zero, _} ->
        raise Knarr.LockFileError, lock_path: lock_path
    end
  end

  @spec delete_lock_file(port, String.t) :: nil
  defp delete_lock_file(ssh, lock_path) do
    SSH.run!(ssh, "rm #{lock_path}")
    nil
  end

  @spec next_release(t) :: release_tuple

  def next_release(%__MODULE__{app_path: app_path, releases: []}),
    do: do_next_release(1, app_path)

  def next_release(%__MODULE__{app_path: app_path, releases: [{last_id, _} | _]}),
    do: do_next_release(last_id + 1, app_path)

  @spec do_next_release(integer, String.t) :: release_tuple
  defp do_next_release(next_id, app_path),
    do: {next_id, Path.join([app_path, @releases_dir, Integer.to_string(next_id)])}

  @spec create_release_dir(t, release_tuple, keyword) :: t
  def create_release_dir(remote, release, opts \\ []) do
    {_id, release_dir} = release
    info("remote: creating release directory: #{release_dir}")

    case remote.releases do
      [] ->
        SSH.run!(remote.ssh, "mkdir #{release_dir}")

      [{_, previous_dir} | _] ->
        reflink = if Keyword.get(opts, :reflink), do: " --reflink", else: " "

        info("remote: copying previous release to speed up rsync")
        SSH.run!(remote.ssh, "cp -r#{reflink} #{previous_dir} #{release_dir}")
    end

    %{remote | releases: [release | remote.releases]}
  end

  @spec clean_releases(t, pos_integer) :: release_tuple_list
  def clean_releases(remote, max_releases),
    do: do_clean_releases(remote, Enum.reverse(remote.releases), max_releases)

  defp do_clean_releases(remote, releases, max_releases, deleted_releases \\ []) do
    case Enum.count(releases) > max_releases do
      true ->
        [oldest | releases] = releases
        delete_release(remote.ssh, oldest)

        do_clean_releases(remote, releases, max_releases, [oldest | deleted_releases])

      false ->
        deleted_releases
    end
  end

  @spec delete_release(port, release_tuple) :: nil
  defp delete_release(ssh, {_id, dir}) do
    SSH.run!(ssh, "rm -r #{dir}")
    nil
  end

  @spec symlink_shared_paths(t, String.t, [String.t]) :: nil

  def symlink_shared_paths(_remote, _release_dir, []) do
    nil
  end

  def symlink_shared_paths(remote, release_dir, [path | paths]) do
    source = Path.join(["..", "..", "shared", path])
    target = Path.join(release_dir, path)

    info("  #{target} -> #{source}")
    SSH.run!(remote.ssh, "ln --symbolic #{source} #{target}")

    symlink_shared_paths(remote, release_dir, paths)
  end

  @spec symlink_current(t, String.t) :: nil
  def symlink_current(remote, release_dir) do
    link_path            = Path.join(remote.app_path, @current_dir)
    relative_release_dir = Path.relative_to(release_dir, remote.app_path)

    SSH.run!(
      remote.ssh,
      "ln --symbolic --force --no-dereference "
      <> "#{relative_release_dir} #{link_path}"
    )

    nil
  end

  @spec run_commands(t, [String.t]) :: nil

  def run_commands(_remote, []) do
    nil
  end

  def run_commands(remote, [command | commands]) do
    info("remote: $ #{command}")
    SSH.run!(remote.ssh, command)
    run_commands(remote, commands)
  end
end
