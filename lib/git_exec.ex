defmodule Breakout.GitExec do

  # %info{conn: conn, channel_id: 0}
  def start(info) do
    %{cmd: cmd} = info

    [bin, repo] = String.split cmd, ~r{\s+}, parts: 2
    # strips 'test.git' and remove any ".."
    repo = repo |> String.strip(?') |> String.replace("..", "")

    info = Dict.merge info, %{bin: bin, repo: repo, port_pid: nil}

    pid = spawn fn -> init(info) end
    {:ok, pid}
  end

  def process_input(pid, data) do
    send pid, {:ssh_cm, :input, data}
  end

  def stop(pid) do
    send pid, :stop
  end
  # end rpc

  defp init(state) do
    {:ok, port_pid} = Breakout.Exec.start(state.bin, ["repos/#{state.repo}"])
    loop %{state| port_pid: port_pid}
  end

  defp loop(state) do
    receive do
      {:ssh_cm, :input, data} ->
        Breakout.Exec.put_input(state.port_pid, data)
        loop(state)
      {:data, :out, input} ->
        # type = 1-stderr, 0-stdout
        :ssh_connection.send(state.conn, state.channel_id, 0, input)
        loop(state)
      {:data, :err, input} ->
        # type = 1-stderr, 0-stdout
        :ssh_connection.send(state.conn, state.channel_id, 1, input)
        loop(state)
      {:exit_status, status} ->
        #IO.puts "Exit status: #{status}"
        :ok = :ssh_connection.exit_status(state.conn, state.channel_id, status)
        :ssh_connection.send_eof(state.conn, state.channel_id)
        loop(state)
      {:DOWN, _ref, :process, _pid, _state} ->
        :ssh_connection.close(state.conn, state.channel_id)
      :stop ->
        Breakout.Exec.stop(state.port_pid)
        loop(state)
      msg ->
        IO.puts "git exec: unexpected msg: #{inspect msg}"
        loop(state)
    end
  end
end
