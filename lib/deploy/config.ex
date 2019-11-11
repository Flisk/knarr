defmodule MixDeploy.Config do

  defmodule MissingValueError do
    defexception [:message]
  end

  defstruct(
    host: nil,
    user: nil,
    port: nil,
    app_path: nil,
    max_releases: nil
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
    target = Keyword.fetch!(config, :target)

    %MixDeploy.Config{
      host: Keyword.fetch!(target, :host),
      user: Keyword.fetch!(target, :user),
      port: Keyword.get(target, :port, 22),
      app_path: Keyword.fetch!(target, :app_path),
      max_releases: Keyword.fetch!(target, :max_releases)
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
