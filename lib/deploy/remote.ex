defmodule MixDeploy.Remote do
  alias MixDeploy.SSH

  @releases_dir "releases"

  @doc """
  Ensure that a remote host is correctly initialized for deployments.
  """
  @spec check_deploy_dirs(port(), String.t()) :: nil
  def check_deploy_dirs(ssh, app_path) do
    SSH.run!(ssh, "cd " <> app_path)
    SSH.run!(ssh, "test -d " <> @releases_dir)
    SSH.run!(ssh, "cd")
    nil
  end

  def clean_releases(ssh, releases, max_releases),
    do: clean_releases(ssh, Enum.reverse(releases), max_releases, [])

  def clean_releases(ssh, releases, max_releases, deleted_releases) do
    case Enum.count(releases) > max_releases do
      true ->
        [oldest | releases] = releases
        delete_release(ssh, oldest)

        clean_releases(ssh, releases, max_releases, [oldest | deleted_releases])

      false ->
        deleted_releases
    end
  end

  defp delete_release(ssh, {_id, dir}),
    do: SSH.run!(ssh, "rm -r #{dir}")

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

  def next_release([], app_path),
    do: next_release(1, app_path)

  def next_release([{last_id, _last_path} | _releases], app_path),
    do: next_release(last_id + 1, app_path)

  def next_release(next_id, app_path) when is_integer(next_id),
    do: {next_id, Path.join([app_path, @releases_dir, Integer.to_string(next_id)])}

  defp parse_release_dir(dir, app_path) do
    basename    = Path.basename(dir)
    release_dir = Path.join([app_path, @releases_dir, basename])

    case Integer.parse(basename) do
      {release_number, ""} -> {release_number, release_dir}
      _ -> raise "invalid release directory: #{release_dir}"
    end
  end
end
