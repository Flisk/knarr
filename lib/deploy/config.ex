defmodule MixDeploy.Config do

  defmodule MissingValueError do
    defexception [:message]
  end

  defstruct(
    host: nil,
    user: nil,
    port: nil,
    app_path: nil,
    max_releases: nil,
    rsync_copy_reflink: nil,

    shared_files: nil,
    shared_directories: nil,

    hooks_after_deploy: nil
  )

  @spec load(String.t()) :: %MixDeploy.Config{}
  def load(name) do
    try do
      name
      |> deploy_config_path()
      |> Config.Reader.read!()
      |> new()
    rescue
      err in [Code.LoadError] ->
        raise err.message

      err in [KeyError] ->
        raise "missing key in deployment configuration: #{err.key}"
    end
  end

  @spec new(keyword()) :: %MixDeploy.Config{}
  def new(config) do
    server = Keyword.fetch!(config, :server)
    hooks  = Keyword.get(config, :hooks, [])
    shared = Keyword.get(config, :shared, [])

    %MixDeploy.Config{
      host: Keyword.fetch!(server, :host),
      user: Keyword.fetch!(server, :user),
      port: Keyword.get(server, :port, 22),
      app_path: Keyword.fetch!(server, :app_path),
      max_releases: Keyword.fetch!(server, :max_releases),
      rsync_copy_reflink: Keyword.get(server, :rsync_copy_reflink, false),

      shared_files: Keyword.get(shared, :files, []),
      shared_directories: Keyword.get(shared, :directories, []),

      hooks_after_deploy: Keyword.get(hooks, :after_deploy, [])
    }
  end
  
  @doc """
  Returns the canonical path for a given deployment configuration
  name.
  """
  @spec deploy_config_path(String.t()) :: String.t()
  def deploy_config_path(name),
    do: "config/deploy/#{name}.exs"

end
