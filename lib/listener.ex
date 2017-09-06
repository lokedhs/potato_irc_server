defmodule Listener do
  use GenServer
#  require PotatoIrcServer.Records
#  alias PotatoIrcServer.Records
  alias PotatoIrcServer.Handler.Channel

  def start_link(%Channel{} = channel) do
    GenServer.start_link(__MODULE__, channel, [])
  end

  def init(%Channel{} = _channel) do
#    {:ok, conn} = :amqp_connection.start Records.amqp_params_network(username: "guest", password: "guest")
#    {:ok, _channel} = :amqp_connection.open_channel conn
    :ok
  end
end
