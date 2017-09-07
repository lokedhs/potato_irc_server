defmodule PotatoIrcServer.Handler do
  use GenServer

  defmodule Connection do
    defstruct irc_connection: nil, amqp_connection: nil, channels: %{}, logged_in: false
  end

  defmodule Channel do
    defstruct potato_channel: nil, irc_channel: nil, pid: nil
  end

  def start!() do
    {:ok, rqt_conn} = AMQP.Connection.open
    {:ok, irc_conn} = ExIrc.Client.start!
    start_link([%Connection{irc_connection: irc_conn, amqp_connection: rqt_conn}])
  end

  def start_link([conn]) do
    GenServer.start_link(__MODULE__, conn, [])
  end

  def init(conn) do
    ExIrc.Client.add_handler conn.irc_connection, self()
    :ok = ExIrc.Client.connect! conn.irc_connection, "localhost", 6667
    {:ok, conn}
  end

  defp make_channel(conn, potato_channel, irc_channel) do
    {:ok, pid} = PotatoIrcServer.ChannelTracker.start!(conn.irc_connection, conn.amqp_connection, potato_channel, irc_channel)
    IO.puts "tracker started: conn=#{inspect(conn)}"
    if conn.logged_in do
      IO.puts "sending logged_in message"
      GenServer.cast(pid, {:logged_in})
    end
    %Channel{potato_channel: potato_channel, irc_channel: irc_channel, pid: pid}
  end

  @doc """
  Handle messages from the client

  Examples:

    def handle_info({:connected, server, port}, _state) do
      IO.puts "Connected to \#{server}:\#{port}"
    end
    def handle_info(:logged_in, _state) do
      IO.puts "Logged in!"
    end
    def handle_info(%IrcMessage{nick: from, cmd: "PRIVMSG", args: ["mynick", msg]}, _state) do
      IO.puts "Received a private message from \#{from}: \#{msg}"
    end
    def handle_info(%IrcMessage{nick: from, cmd: "PRIVMSG", args: [to, msg]}, _state) do
      IO.puts "Received a message in \#{to} from \#{from}: \#{msg}"
    end
  """
  def handle_info({:connected, server, port}, conn) do
    debug "Connected to #{server}:#{port}, conn: #{inspect(conn)}"
    :ok = ExIrc.Client.logon conn.irc_connection, "", "potato", "potato", "Potato link bot"
    {:noreply, conn}
  end

  def handle_info(:logged_in, conn) do
    debug "Logged in to server, conn: #{inspect(conn)}"
    Enum.each conn.channels, fn({_, chan}) -> GenServer.cast(chan.pid, {:logged_in}) end
    {:noreply, %{conn | logged_in: true}}
  end

  def handle_info(:disconnected, conn) do
    debug "Disconnected from server"
    {:noreply, conn}
  end

  def handle_info({:joined, channel}, conn) do
    debug "Joined #{channel}"
    {:noreply, conn}
  end

  def handle_info({:joined, channel, user}, conn) do
    debug "#{user} joined #{channel}"
    {:noreply, conn}
  end

  def handle_info({:topic_changed, channel, topic}, conn) do
    debug "#{channel} topic changed to #{topic}"
    {:noreply, conn}
  end

  def handle_info({:nick_changed, nick}, conn) do
    debug "We changed our nick to #{nick}"
    {:noreply, conn}
  end

  def handle_info({:nick_changed, old_nick, new_nick}, conn) do
    debug "#{old_nick} changed their nick to #{new_nick}"
    {:noreply, conn}
  end

  def handle_info({:parted, channel}, conn) do
    debug "We left #{channel}"
    {:noreply, conn}
  end

  def handle_info({:parted, channel, sender}, conn) do
    nick = sender.nick
    debug "#{nick} left #{channel}"
    {:noreply, conn}
  end

  def handle_info({:invited, sender, channel}, conn) do
    by = sender.nick
    debug "#{by} invited us to #{channel}"
    {:noreply, conn}
  end

  def handle_info({:kicked, sender, channel}, conn) do
    by = sender.nick
    debug "We were kicked from #{channel} by #{by}"
    {:noreply, conn}
  end

  def handle_info({:kicked, nick, sender, channel}, conn) do
    by = sender.nick
    debug "#{nick} was kicked from #{channel} by #{by}"
    {:noreply, conn}
  end

  def handle_info({:received, message, sender}, conn) do
    from = sender.nick
    debug "#{from} sent us a private message: #{message}"
    {:noreply, conn}
  end

  def handle_info({:received, message, sender, channel}, conn) do
    from = sender.nick
    debug "#{from} sent a message to #{channel}: #{message}"
    channel = conn.channels[channel]
    if channel do
      GenServer.cast channel.pid, {:recv_message, %{from: from, content: message}}
    end
    {:noreply, conn}
  end

  def handle_info({:mentioned, message, sender, channel}, conn) do
    from = sender.nick
    debug "#{from} mentioned us in #{channel}: #{message}"
    {:noreply, conn}
  end

  def handle_info({:me, message, sender, channel}, conn) do
    from = sender.nick
    debug "* #{from} #{message} in #{channel}"
    {:noreply, conn}
  end

  # This is an example of how you can manually catch commands if ExIrc.Client doesn't send a specific message for it
  def handle_info(%IrcMessage{nick: from, cmd: "PRIVMSG", args: ["testnick", msg]}, conn) do
    debug "Received a private message from #{from}: #{msg}"
    {:noreply, conn}
  end

  def handle_info(%IrcMessage{nick: from, cmd: "PRIVMSG", args: [to, msg]}, conn) do
    debug "Received a message in #{to} from #{from}: #{msg}"
    {:noreply, conn}
  end

  # Catch-all for messages you don't care about
  def handle_info(msg, conn) do
    code = elem(msg, 0)
    debug "Received IrcMessage: #{code}"
    {:noreply, conn}
  end

  def handle_call({:add_channel, potato_channel, irc_channel}, _from, conn) do
    cond do
      conn.channels[irc_channel] ->
        {:reply, {:error, :irc_channel_already_exists}, conn}
      Enum.find(conn.channels, fn({_, v}) -> v.potato_channel == potato_channel end) ->
        {:reply, {:error, :potato_channel_already_exists}, conn}
      true ->
        IO.puts "Adding #{potato_channel} to server as #{irc_channel}"
        channel = make_channel(conn, potato_channel, irc_channel)
        {:reply, :ok, %{conn | channels: Map.put(conn.channels, irc_channel, channel)}}
    end    
  end

  defp debug(msg) do
    IO.puts "Debug: " <> msg
  end
end
