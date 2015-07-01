defmodule Breakout.ExecTest do
  use ExUnit.Case

  test "echo output" do
    {:ok, pid} = Breakout.Exec.start("echo", ["hello"])

    assert_receive {:data, :out, "hello\n"}, 200
    assert_receive {:exit_status, 0}, 200
    assert_receive {:DOWN, _ref, :process, ^pid, :normal}
  end
end
