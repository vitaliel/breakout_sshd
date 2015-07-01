defmodule Breakout.Sshd.Channel do
  @behaviour :ssh_daemon_channel

  alias Breakout.GitExec

  def init(_options) do
    {:ok, %{channel: nil, cm: nil, exec_pid: nil}}
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
  def handle_ssh_msg({:ssh_cm, _conn,
      {:data, _channel_id, _type, data}}, state) do
    #IO.puts "handle_ssh_msg data len:#{String.length data} #{inspect data}"

    GitExec.process_input state.exec_pid, data

    {:ok, state}
  end

  def handle_ssh_msg({:ssh_cm, _, {:eof, channel_id}}, state) do
    #IO.puts "ssh_cm receive eof, #{channel_id}"
    GitExec.stop state.exec_pid

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

    {:ok, pid} = GitExec.start %{conn: conn, channel_id: channel_id, cmd: to_string(cmd)}
    :ssh_connection.reply_request(conn, want_reply, :success, channel_id)

    {:ok, %{state | exec_pid: pid}}
  end

  def handle_ssh_msg({:ssh_cm, _, {:exit_signal, channel_id, _, error, _}}, state) do
    :logger.error error
    {:stop, channel_id, state}
  end

  def handle_ssh_msg({:ssh_cm, _, {:exit_status, channel_id, 0}}, state) do
    IO.puts "ssh_cm exit_status, #{channel_id}"
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
    :logger.info "terminated reason #{inspect reason}"
    #IO.puts "terminate, port #{inspect Process.info(state.exec_pid)}"
  end
end
