defmodule PotatoIrcServer do
  alias PotatoIrcServer.Handler

  @channels Application.get_env :potato_irc_server, :channels

  def start_server do
    # TODO: This should be a link
    {:ok, pid} = Handler.start!
    Enum.each @channels, fn([potato_channel: potato_channel, irc_channel: irc_channel]) ->
      add_channel pid, potato_channel, irc_channel
    end
    {:ok, pid}
  end

  def add_channel(pid, potato_channel, irc_channel) do
    GenServer.call pid, {:add_channel, potato_channel, irc_channel}
  end
end
