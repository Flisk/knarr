defmodule Knarr.Remote do
  alias Knarr.SSH

  @type release_tuple      :: {pos_integer, String.t}
  @type release_tuple_list :: [release_tuple]

  @releases_dir "releases"
  @shared_dir   "shared"

  @doc """
  Ensure that a remote host is correctly initialized for deployments.
  """
  @spec check_deploy_dirs(port, String.t) :: nil
  def check_deploy_dirs(ssh, app_path) do
    SSH.run!(ssh, "cd " <> app_path)
    SSH.run!(ssh, "test -d " <> @releases_dir)
    SSH.run!(ssh, "test -d " <> @shared_dir)
    SSH.run!(ssh, "cd")
    nil
  end

  @spec clean_releases(port, release_tuple_list, pos_integer) :: release_tuple_list
  def clean_releases(ssh, releases, max_releases),
    do: do_clean_releases(ssh, Enum.reverse(releases), max_releases)

  defp do_clean_releases(ssh, releases, max_releases, deleted_releases \\ []) do
    case Enum.count(releases) > max_releases do
      true ->
        [oldest | releases] = releases
        delete_release(ssh, oldest)

        do_clean_releases(ssh, releases, max_releases, [oldest | deleted_releases])

      false ->
        deleted_releases
    end
  end

  @spec delete_release(port, release_tuple) :: nil
  defp delete_release(ssh, {_id, dir}), do: SSH.run!(ssh, "rm -r #{dir}")

  @spec find_releases(port, String.t) :: release_tuple_list
  def find_releases(ssh, app_path) do
    releases_path = Path.join(app_path, @releases_dir)
    SSH.run!(ssh, "cd " <> releases_path)

    find_output = SSH.run!(ssh, "find . -path './*' -prune -type d")

    SSH.run!(ssh, "cd")

    find_output
    |> Stream.map(&(parse_release_dir(&1, app_path)))
    |> Enum.sort()
    |> Enum.reverse()
  end

  @spec next_release(release_tuple_list, String.t) :: release_tuple

  def next_release([], app_path), do: do_next_release(1, app_path)

  def next_release([{last_id, _last_path} | _releases], app_path),
    do: do_next_release(last_id + 1, app_path)

  @spec do_next_release(integer, String.t) :: release_tuple
  defp do_next_release(next_id, app_path),
    do: {next_id, Path.join([app_path, @releases_dir, Integer.to_string(next_id)])}

  @spec parse_release_dir(String.t, String.t) :: release_tuple
  defp parse_release_dir(dir, app_path) do
    basename    = Path.basename(dir)
    release_dir = Path.join([app_path, @releases_dir, basename])

    case Integer.parse(basename) do
      {release_number, ""} -> {release_number, release_dir}
      _ -> raise "invalid release directory: #{release_dir}"
    end
  end
end
