defmodule Knarr.SSH do
  @moduledoc """
  OpenSSH session management based on Erlang ports.
  """

  @debug false
  
  @doc """
  Start an OpenSSH client process connecting to the specified server.
  
  Returns the port used for communication with the ssh process.
  """
  @spec connect(String.t, String.t, pos_integer) :: port
  def connect(host, user, port) do
    port = Port.open(
      {:spawn_executable, find_ssh_executable()},
      [
        :binary,
        args: ssh_args(user, host, port),
        line: 1000
      ]
    )

    Port.monitor(port)

    # dummy command to skip login messages
    {0, _} = run(port, "true")

    port
  end

  @doc """
  Same as run, but returns only a list of output lines with no exit
  code. An error is raised if the exit code is non-zero.
  """
  @spec run!(port, String.t) :: [String.t]
  def run!(port, command) do
    case run(port, command) do
      {0, output}   -> output
      {non_zero, _} -> raise "command #{command} returned #{non_zero}"
    end
  end

  @doc """
  Run a shell command on the connected server.
  """
  @spec run(port, String.t, boolean) :: {integer, [String.t]} | integer
  def run(port, command, receive_result \\ true) do
    end_token = new_end_token()
    command   = command <> " ; printf '\\n%s\\n%s\\n' #{end_token} $?\n"

    if @debug, do: IO.puts("-> #{inspect command}")
    send(port, {self(), {:command, command}})

    case receive_result do
      true  -> receive_command_result(port, end_token)
      false -> end_token
    end
  end

  @spec receive_command_result(port, String.t, [String.t]) :: [String.t]
  def receive_command_result(port, end_token, lines \\ []) do
    case receive_line(port) do
      ^end_token ->
        lines = delete_trailing_empty_line(lines)
        line  = receive_line(port)

        {status_code, ""} = Integer.parse(line)

        {status_code, lines}

      line ->
        receive_command_result(port, end_token, lines ++ [line])
    end
  end

  @spec find_ssh_executable :: String.t
  defp find_ssh_executable do
    case System.find_executable("ssh") do
      nil ->
        raise "ssh executable not found"

      executable ->
        executable
    end
  end

  @spec ssh_args(String.t, String.t, pos_integer) :: [String.t]
  defp ssh_args(user, host, port) when is_integer(port),
    do: ssh_args(user, host, Integer.to_string(port))

  @spec ssh_args(String.t, String.t, String.t) :: [String.t]
  defp ssh_args(user, host, port) do
    [
      # passing this option explicitly mutes a warning we don't really
      # care about
      "-o", "RequestTTY=no",

      "-l", user,
      "-p", port,

      host
    ]
  end

  @spec new_end_token :: integer
  defp new_end_token,
    do: Enum.random(1000000..1000000000) |> Integer.to_string()

  @spec receive_line(port, String.t | nil) :: String.t
  defp receive_line(port, partial_line \\ nil)

  defp receive_line(port, nil) do
    case receive_or_die(port) do
      {:noeol, partial_line} -> receive_line(port, partial_line)
      {:eol, line}           -> line
    end
  end

  defp receive_line(port, partial_line) do
    case receive_or_die(port) do
      {:eol, end_of_line} ->
        partial_line <> end_of_line

      {:noeol, next_line_part} ->
        receive_line(port, partial_line <> next_line_part)
    end
  end

  @spec delete_trailing_empty_line([String.t]) :: [String.t]
  defp delete_trailing_empty_line(lines) do
    case List.last(lines) do
      "" -> List.delete_at(lines, -1)
      _  -> lines
    end
  end

  @spec receive_or_die(port) :: {:eol | :noeol, String.t}
  defp receive_or_die(port) do
    receive do
      {:DOWN, _ref, :port, ^port, reason} ->
        raise "process has died unexpectedly: #{reason}"

      {^port, {:data, data}} ->
        if @debug, do: IO.puts("<- #{inspect data}")
        data
    end
  end
end
