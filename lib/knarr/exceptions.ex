defmodule Knarr.UsageError do
  defexception [:message]
end

defmodule Knarr.RemoteCommandError do
  defexception [:message]

  @impl true
  def exception([exit_code: exit_code, command: command]),
    do: %__MODULE__{message: "command `#{command}` exited with #{exit_code}"}
end

defmodule Knarr.RemoteDirsError do
  defexception [:message]

  @impl true
  def exception([app_path: app_path]) do
    %__MODULE__{
      message: """
      Remote directory layout check failed.

      Ensure these directories exist and are accessible to your
      deployment user:
      * #{app_path}
      * #{app_path}/releases
      * #{app_path}/shared
      """
    }
  end
end

defmodule Knarr.LockFileError do
  defexception [:message]

  @impl true
  def exception([lock_path: lock_path]) do
    %__MODULE__{
      message: """
      Failed to acquire deployment lock.

      If you are certain that no other deployments are running, this
      error was caused by a stale lock file. Try again after deleting
      '#{lock_path}' on the remote.
      """
    }
  end
end
