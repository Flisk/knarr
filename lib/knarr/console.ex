defmodule Knarr.Console do
  @moduledoc "Console output helpers."

  @prefix "knarr: "

  @ansi_bold_blue  "\x1b[1;34m"
  @ansi_bold_green "\x1b[1;32m"
  @ansi_reset      "\x1b[0m"

  def info(message), do: print(@ansi_bold_blue, message)

  def success(message), do: print(@ansi_bold_green, message)

  defp print(prefix_color, message) do
    # https://no-color.org/
    case System.get_env("NO_COLOR") do
      nil -> [prefix_color, @prefix, @ansi_reset, message]
      _   -> [@prefix, message]
    end
    |> Enum.join()
    |> Mix.shell().info()
  end
end
