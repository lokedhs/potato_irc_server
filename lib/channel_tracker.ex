defmodule PotatoIrcServer.ChannelTracker do
  use GenServer

  defmodule State do
    defstruct irc_connection: nil, amqp_connection: nil
  end

  def start!(irc_conn, rqt_conn, _potato_channel, _irc_channel) do
    start_link([%State{irc_connection: irc_conn, amqp_connection: rqt_conn}])
  end

  def start_link([state]) do
    GenServer.start_link(__MODULE__, state, [])
  end

  def init(state) do
    {:ok, channel} = AMQP.Channel.open(state.amqp_connection)
    {:ok, %{queue: queue}} = AMQP.Queue.declare(channel, "", [auto_delete: true])
    :ok = AMQP.Queue.bind(channel, queue, "channel-content-ex", [routing_key: "#"])
    {:ok, _consumer_tag} = AMQP.Basic.consume(channel, queue)
    {:ok, state}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: _delivery_tag, redelivered: _redelivered}}, state) do
    IO.puts "Got rabbitmq message: #{inspect(payload)}"
    {:noreply, state}
  end

  def handle_info({:basic_consume_ok, _}, state) do
    {:noreply, state}
  end

  def handle_info(req, state) do
    IO.puts "Unhandled info #{inspect(req)}"
    {:noreply, state}
  end
end
