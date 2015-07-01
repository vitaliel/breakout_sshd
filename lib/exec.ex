defmodule Breakout.Exec do

  @driver "erl_port"

  def run(cmd, args \\ [], options \\ %{}) do
    mon_pid = self

    spawn fn ->
      {:ok, pid} = start(cmd, args, options)
      collect(%{status: nil, out: "", err: "", mon_pid: mon_pid})
    end

    receive do
      {:exec_result, msg} ->
        msg
      msg ->
        raise "unexpected #{inspect msg}"
    end
  end

  def start(cmd, args \\ [], options \\ %{}) do
    parent = self
    pid = spawn fn -> init(parent, cmd, args, options) end
    Process.monitor pid

    {:ok, pid}
  end

  def put_input(pid, data) do
    send pid, {:input, data}
  end

  def stop(pid) do
    send pid, :stop
  end

  defp init(parent, cmd, args, params) do
    driver_path = case :os.find_executable(:erlang.binary_to_list(@driver)) do
      false -> raise "Can not find driver #{@driver}"
      path -> path
    end

    if exe = :os.find_executable(:erlang.binary_to_list(cmd)) do
      cmd = List.to_string(exe)
    end

    options = [{:args, ["--", cmd | args]},
      {:packet, 2}, :binary, :use_stdio, :exit_status, :hide]

    env = Dict.get(params, :env)

    if env do
      options = [{:env, env} | options]
    end

    cd = Dict.get(params, :cd)

    if cd do
      options = [{:cd, cd} | options]
    end

    #IO.puts inspect(options)

    port = Port.open(
      {:spawn_executable, driver_path},
      options
    )

    state = %{port: port, parent: parent}
    loop(state)
  end

  defp loop(state) do
    receive do
      {:input, data} ->
        #IO.puts "send port data: #{String.length(data) + 1}"
        Port.command(state.port, <<0>> <> data)
        loop(state)
      :stop ->
        Port.command(state.port, <<1>>)
        # send port, {self, :close}
        loop(state)
      {_from, {:data, <<0, input::binary>>}} ->
        send state.parent, {:data, :out, input}
        loop(state)
      {_from, {:data, <<1, input::binary>>}} ->
        send state.parent, {:data, :err, input}
        loop(state)
      {_from, {:exit_status, status}} ->
        send state.parent, {:exit_status, status}
      msg ->
        IO.puts "unexpected msg: #{inspect msg}"
        loop(state)
    end
  end

  defp collect(state) do
    receive do
      {:data, :out, input} ->
        collect(%{state| out: state.out <> input})
      {:data, :err, input} ->
        collect(%{state| err: state.err <> input})
      {:DOWN, _ref, :process, _pid, _state} ->
        send state.mon_pid, {:exec_result, state}
      {:exit_status, status} ->
        collect(%{state | status: status})
    end
  end
end
