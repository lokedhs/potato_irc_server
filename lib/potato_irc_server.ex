defmodule PotatoIrcServer do
  def start_server do
    # TODO: This should be a link
    {:ok, pid} = PotatoHandler.start!
    # add_channel pid, "b9e7d33c4fb7c55f4cdd946ff100506f", "#bar"
    pid
  end

  def add_channel(pid, potato_channel, irc_channel) do
    GenServer.call pid, {:add_channel, potato_channel, irc_channel}
  end
end
