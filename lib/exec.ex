defmodule Breakout.Exec do
  def start(cmd, args) do
    pid = spawn fn -> init(cmd, args) end
    {:ok, pid}
  end

  def init(cmd, args) do
    options = [in: :receive, out: {:send, self}, err: {:send, self}]
    process = Porcelain.spawn(cmd, args, options)
    state = %{proc: process}
    loop(state)
  end

  def loop(state) do
    receive do
      {_from, :data, :out, data} ->
        IO.puts "out: #{inspect data}"
      {_from, :data, :err, data} ->
        IO.puts "err: #{inspect data}"
      msg ->
        IO.puts "unexpected msg: #{inspect msg}"
    end

    IO.puts "loop: #{inspect state}"
    loop(state)
  end
end
