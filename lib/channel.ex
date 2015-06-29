defmodule Breakout.Sshd.Channel do
  @behaviour :ssh_daemon_channel

  def init(options) do
    IO.puts "init options #{inspect options}"
    {:ok, %{channel: nil, cm: nil}}
  end

  def handle_call(msg, _from, state) do
    IO.puts "call msg #{inspect msg}"
    {:reply, [], state}
  end

  def handle_cast(msg, state) do
    IO.puts "cast msg #{inspect msg}"
    {:noreply, state}
  end

  def handle_msg({:ssh_channel_up, channel_id, conn}, state) do
    {:ok, %{state | channel: channel_id, cm: conn}}
  end

  def handle_msg({'EXIT', _group, _reason}, %{channel: channel_id} = state) do
    {:stop, channel_id,  state}
  end

  def handle_msg(msg, state) do
    IO.puts "handle_msg msg #{inspect msg}"
    {:ok, state}
  end

  # data requests
  def handle_ssh_msg({:ssh_cm, conn,
      {:data, _channel_id, _type, data}}, state) do
    IO.puts "handle_ssh_msg #{inspect data}"
    # TODO forward to git command
    {:ok, state}
  end

  # pty requests
  def handle_ssh_msg({:ssh_cm, conn,
      {:pty, channel_id, want_reply, _options}}, state) do
    :ssh_connection.reply_request(conn, want_reply, :failure, channel_id)
    {:ok, state}
  end

  # env requests
  def handle_ssh_msg({:ssh_cm, conn,
      {:env, channel_id, want_reply, _var, _value}}, state) do
    :ssh_connection.reply_request(conn, want_reply, :failure, channel_id)
    {:ok, state}
  end

  # shell requests
  def handle_ssh_msg({:ssh_cm, conn,
      {:shell, channel_id, want_reply}}, state) do
    :ssh_connection.reply_request(conn, want_reply, :failure, channel_id)
    {:ok, state}
  end

  # exec requests
  def handle_ssh_msg({:ssh_cm, conn,
      {:exec, channel_id, want_reply, cmd}}, state) do

    :ssh_connection.reply_request(conn, want_reply, :success, channel_id)
    :ssh_connection.exit_status(conn, channel_id, Status)
    :ssh_connection.send_eof(ConnectionHandler, channel_id)
    {:stop, channel_id, %{state | channel: channel_id, cm: conn}}
  end

  def handle_ssh_msg({:ssh_cm, _, {:exit_signal, channel_id, _, error, _}}, state) do
    # Report = io_lib:format("Connection closed by peer ~n Error ~p~n",
    #      [Error]),
    # error_logger:error_report(Report),
    {:stop, channel_id,  state}
  end

  def handle_ssh_msg({:ssh_cm, _, {:exit_status, channel_id, 0}}, state) do
    {:stop, channel_id, state}
  end

  def handle_ssh_msg({:ssh_cm, _, {:exit_status, channel_id, status}}, state) do
    :logger.info "Connection closed by peer \n Status #{inspect status}\n"
    {:stop, channel_id, state}
  end

  def handle_ssh_msg(msg, state) do
    IO.puts "handle_ssh_msg msg #{inspect msg}"
    {:ok, state}
  end

  def terminate(reason, _state) do
    IO.puts "handle_ssh_msg msg #{inspect reason}"
  end
end
