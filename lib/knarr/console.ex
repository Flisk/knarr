defmodule Knarr.Console do
  @moduledoc "Console output helpers."

  @prefix          "knarr: "

  @ansi_bold_blue  "\x1b[1;34m"
  @ansi_bold_green "\x1b[1;32m"
  @ansi_reset      "\x1b[0m"

  def info(message), do: do_info(@ansi_bold_blue, message)

  def success(message), do: do_info(@ansi_bold_green, message)

  defp do_info(prefix_color, message) do
    [prefix_color, @prefix, @ansi_reset, message]
    |> Enum.join()
    |> Mix.shell().info()
  end
end
