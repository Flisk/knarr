defmodule Knarr.Tasks.Local do
  @moduledoc """
  Deployment tasks that run on the local system.
  """

  import Knarr.Console, only: [info: 1]

  @spec build_release(map) :: map
  def build_release(%{config: config, build_dir: build_dir} = state) do
    ensure_required_env(config.require_mix_env)

    info("building release in #{build_dir}")
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

  @spec ensure_required_env([atom] | atom | nil) :: nil

  def ensure_required_env(nil) do
    nil
  end

  def ensure_required_env(atom) when is_atom(atom) do
    ensure_required_env([atom])
  end

  def ensure_required_env(atoms) when is_list(atoms) do
    unless Enum.member?(atoms, Mix.env()),
      do: raise Knarr.RequiredEnvError, required_envs: atoms
  end

  @spec rsync_release(map) :: map
  def rsync_release(
    %{
      config: config,
      build_dir: build_dir,
      remote_release_dir: remote_release_dir
    } = state
  ) do
    info("deploying release with rsync")

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

  defp collapse_trailing_slashes(string),
    do: String.trim_trailing(string, "/") <> "/"
end
