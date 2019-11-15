defmodule Knarr.Deploy do
  alias Knarr.Remote
  alias Knarr.SSH

  def run(args) do
    args
    |> initialize()
    |> build_release()
    |> remote_connect()
    |> remote_create_release_dir()
    |> rsync_deploy_release()
    |> remote_link_shared_paths()
    |> remote_update_current_symlink()
    |> remote_run_hooks()
    |> remote_clean_releases()
    |> report_success()
  end

  defp initialize(args) do
    case args do
      [] ->
        raise "missing deployment config argument"

      [config_name] ->
        %{
          config: Knarr.Config.load(config_name),
          build_dir: "_build/knarr"
        }

      _ ->
        raise "too many arguments"
    end
  end

  defp build_release(%{build_dir: build_dir} = state) do
    info("Switching Mix to :prod environment")
    Mix.env(:prod)

    info("Building release in #{build_dir}")
    Mix.Task.run(
      "release",
      [
        "--quiet",
        "--overwrite",
        "--path", build_dir
      ]
    )

    state
  end

  defp remote_connect(%{config: config} = state) do
    info("Connecting to #{config.host}:#{config.port} as #{config.user}")
    ssh = SSH.connect(config.host, config.user, config.port)

    info("remote: Verifying directory structure")
    Remote.check_deploy_dirs(ssh, config.app_path)

    Map.put(state, :ssh, ssh)
  end

  defp remote_create_release_dir(%{ssh: ssh, config: config} = state) do
    releases = Remote.find_releases(ssh, config.app_path)
    next_release = Remote.next_release(releases, config.app_path)

    {_release_id, release_dir} = next_release

    info("remote: Creating release directory: #{release_dir}")

    case releases do
      [] ->
        SSH.run!(ssh, "mkdir #{release_dir}")

      [{_previous_id, previous_dir} | _] ->
        reflink = if config.rsync_copy_reflink, do: "--reflink", else: ""

        info("remote: Copying previous release dir to speed up rsync")
        SSH.run!(ssh, "cp -r #{reflink} #{previous_dir} #{release_dir}")
    end

    state
    |> Map.put(:releases, [next_release | releases])
    |> Map.put(:remote_release_dir, release_dir)
  end

  defp rsync_deploy_release(
    %{
      config: config,
      build_dir: build_dir,
      remote_release_dir: remote_release_dir
    } = state
  ) do
    info("Deploying release with rsync")

    remote_release_dir = collapse_trailing_slashes(remote_release_dir)
    build_dir          = collapse_trailing_slashes(build_dir)

    rsync_target       = "#{config.host}:#{remote_release_dir}"

    rsync_args = [
      "--archive",
      "--delete",
      "--rsh=ssh -l #{config.user} -p #{config.port}",
      build_dir,
      rsync_target
    ]

    {_, 0} = System.cmd("rsync", rsync_args, into: IO.stream(:stdio, :line))

    state
  end

  defp remote_link_shared_paths(
    %{
      ssh: ssh,
      config: config,
      remote_release_dir: release_dir
    } = state
  ) do
    info("Linking shared paths")

    symlink_shared_paths(ssh, release_dir, config.shared_files)
    symlink_shared_paths(ssh, release_dir, config.shared_directories)

    state
  end

  defp symlink_shared_paths(_, _, []), do: nil

  defp symlink_shared_paths(ssh, release_dir, [path | paths]) do
    source = Path.join(["..", "..", "shared", path])
    target = Path.join(release_dir, path)

    info("  #{target} -> #{source}")
    SSH.run!(ssh, "ln --symbolic #{source} #{target}")

    symlink_shared_paths(ssh, release_dir, paths)
  end

  defp remote_update_current_symlink(
    %{
      ssh: ssh,
      config: config,
      remote_release_dir: release_dir
    } = state
  ) do
    current_link_path    = Path.join(config.app_path, "current")
    relative_release_dir = Path.relative_to(release_dir, config.app_path)

    info("Linking #{current_link_path} to #{relative_release_dir}")

    SSH.run!(
      ssh,
      "ln --symbolic --force --no-dereference "
      <> "#{relative_release_dir} #{current_link_path}"
    )

    state
  end

  defp remote_run_hooks(%{ssh: ssh, config: config} = state) do
    info("Running after_deploy hooks")
    run_hooks(ssh, config.hooks_after_deploy)
    state
  end

  defp run_hooks(_ssh, []), do: nil

  defp run_hooks(ssh, [command | remaining_commands]) do
    info("remote: $ #{command}")
    SSH.run!(ssh, command)
    run_hooks(ssh, remaining_commands)
  end

  defp remote_clean_releases(
    %{
      ssh: ssh,
      config: config,
      releases: releases
    } = state
  ) do
    deleted = Remote.clean_releases(ssh, releases, config.max_releases)

    case Enum.empty?(deleted) do
      true -> info("No old releases deleted")

      false ->
        deleted =
          deleted
          |> Stream.map(fn {_id, dir} -> dir end)
          |> Enum.join(", ")

        info("Old releases deleted: #{deleted}")
    end

    state
  end

  defp report_success(state),
    do: success("Release #{state[:remote_release_dir]} deployed successfully!")

  defp collapse_trailing_slashes(string),
    do: String.trim_trailing(string, "/") <> "/"

  @ansi_bold_blue  "\x1b[1;34m"
  @ansi_bold_green "\x1b[1;32m"
  @ansi_reset      "\x1b[0m"

  defp info(message) do
    [@ansi_bold_blue, "knarr: ", @ansi_reset, message]
    |> Enum.join()
    |> Mix.shell().info()
  end

  defp success(message) do
    [@ansi_bold_green, "knarr: ", @ansi_reset, message]
    |> Enum.join()
    |> Mix.shell().info()
  end
end
