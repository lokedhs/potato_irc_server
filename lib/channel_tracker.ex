defmodule PotatoIrcServer.ChannelTracker do
  use GenServer

  @send_message_exchange "chat-image-response-ex"
  @receive_message_exchange "message-send-ex"
  @potato_user Application.get_env(:potato_irc_server, :potato_user)

  defmodule State do
    defstruct irc_connection: nil, amqp_connection: nil,
      potato_channel: nil, irc_channel: nil
  end

  def start!(irc_conn, rqt_conn, potato_channel, irc_channel) do
    {:ok, channel} = AMQP.Channel.open(rqt_conn)
    start_link([%State{irc_connection: irc_conn, amqp_connection: channel,
                       potato_channel: potato_channel, irc_channel: irc_channel}])
  end

  def start_link([state]) do
    GenServer.start_link(__MODULE__, state, [])
  end

  def init(state) do
    {:ok, %{queue: queue}} = AMQP.Queue.declare(state.amqp_connection, "", [auto_delete: true])
    :ok = AMQP.Queue.bind(state.amqp_connection, queue, @receive_message_exchange, [routing_key: "*." <> state.potato_channel <> ".*"])
    {:ok, _consumer_tag} = AMQP.Basic.consume(state.amqp_connection, queue)
    {:ok, state}
  end

  defp escape_string(s) do
    Regex.replace ~r/\"/, s, "\\\""
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: _delivery_tag, redelivered: _redelivered}}, state) do
    IO.puts "Got rabbitmq message: #{inspect(payload)}"
    parsed = Poison.decode!(payload)
    :ok = ExIrc.Client.msg state.irc_connection, :privmsg, state.irc_channel, "From: #{parsed["from_name"]}: #{parsed["text"]}"
    {:noreply, state}
  end

  def handle_info({:basic_consume_ok, _}, state) do
    {:noreply, state}
  end

  def handle_info(req, state) do
    IO.puts "Unhandled info #{inspect(req)}"
    {:noreply, state}
  end

  def handle_cast({:logged_in}, state) do
    :ok = ExIrc.Client.join state.irc_connection, state.irc_channel
    {:noreply, state}
  end

  def handle_cast({:recv_message, msg}, state) do
    %{from: from, content: content} = msg
    payload = format_potato_message state.potato_channel, "IRC: #{from}: #{content}"
    :ok = AMQP.Basic.publish state.amqp_connection, @send_message_exchange, "", payload
    {:noreply, state}
  end

  defp format_potato_message(channel, text) do
    "(:POST (\"#{escape_string(channel)}\" :TEXT \"#{escape_string(text)}\" :SENDER \"#{potato_user}\"))"
  end
end
