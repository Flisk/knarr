defmodule RemoteTest do
  use ExUnit.Case
  alias Knarr.Remote

  doctest Knarr.Remote

  test "next_release" do
    releases = [
      {4, "app/releases/4"},
      {3, "app/releases/3"},
      {2, "app/releases/2"},
      {1, "app/releases/1"}
    ]

    assert Remote.next_release([], "app") == {1, "app/releases/1"}
    assert Remote.next_release(releases, "app") == {5, "app/releases/5"}
  end
end
