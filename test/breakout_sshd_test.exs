defmodule Breakout.SshdTest do
  use ExUnit.Case, async: true

  alias Breakout.Exec

  setup do
    :random.seed(:os.timestamp)
    dir = "tmp/dir#{:random.uniform}"

    on_exit fn ->
      File.rm_rf! dir
    end

    {:ok, cwd} = File.cwd

    {:ok, dir: dir, cwd: cwd, env: [{'GIT_SSH', :erlang.binary_to_list(cwd <> "/vendor/ssh_erl")}]}
  end

  test "git ls-remote", context do
    {:ok, pid} = Exec.start("git", ["ls-remote", "git@localhost:test.git"],
      %{env: context[:env]})
    assert_receive {:data, :out, "d4d4c974a21b1a4e14ba939a7e527a821caba709\tHEAD\nd4d4c974a21b1a4e14ba939a7e527a821caba709\trefs/heads/master\n"}, 500
    assert_receive {:exit_status, 0}, 200
    assert_receive {:DOWN, _ref, :process, ^pid, :normal}
  end

  test "git clone", context do
    dir = context[:dir]
    File.mkdir_p! dir

    {:ok, pid} = Exec.start("git", ["clone", "-q", "git@localhost:test.git"],
      %{cd: context[:cwd] <> "/" <> dir, env: context[:env]}
    )
    assert_receive {:exit_status, 0}, 500
    assert_receive {:DOWN, _ref, :process, ^pid, :normal}
  end

  test "git push", context do
    File.rm_rf! "repos/test_push.git"
    File.cp_r! "repos/test.git", "repos/test_push.git"
    dir = context[:dir]
    File.mkdir_p! dir
    {:ok, cwd} = File.cwd
    work_dir = Path.join cwd, dir

    %{status: 0} = Exec.run("git", ["clone", "-q", "git@localhost:test_push.git"],
      %{cd: work_dir, env: context[:env]}
    )

    wc_dir = Path.join work_dir, "test_push"
    path = Path.join wc_dir, "let.txt"
    File.write!(path, "Hello\n")
    %{status: 0} = Exec.run("git", ["add", "."], %{cd: wc_dir})
    # env: [{'GIT_DIR', to_char_list wc_dir}]
    %{status: 0} = Exec.run("git", ["commit", "-m", "new file"], %{cd: wc_dir})
    %{status: 0} = Exec.run("git", ["push", "-q"], %{cd: wc_dir, env: context[:env]})
    File.rm_rf! "repos/test_push.git"
  end
end
