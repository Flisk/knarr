defmodule RemoteTest do
  use ExUnit.Case
  alias Knarr.Remote

  doctest Knarr.Remote

  test "next_release" do
    pristine_remote = %Remote{
      app_path: "app",
      releases: []
    }

    remote_with_some_releases = %{
      pristine_remote | releases: [
        {4, "app/releases/4"},
        {3, "app/releases/3"},
        {2, "app/releases/2"},
        {1, "app/releases/1"}
      ]
    }

    assert Remote.next_release(pristine_remote) == {1, "app/releases/1"}
    assert Remote.next_release(remote_with_some_releases) == {5, "app/releases/5"}
  end
end
