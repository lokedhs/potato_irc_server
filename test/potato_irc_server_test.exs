defmodule PotatoIrcServerTest do
  use ExUnit.Case
  doctest PotatoIrcServer

  test "greets the world" do
    assert PotatoIrcServer.hello() == :world
  end
end
