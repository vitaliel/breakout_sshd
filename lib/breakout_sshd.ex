defmodule Breakout.Sshd do
  use Application

  def start(_type, _args) do
    port = config :port
    IO.puts "Listen on #{port}"
    options = [
      user_dir: to_char_list(config(:user_dir)),
      system_dir: to_char_list(config(:system_dir)),
      auth_methods: 'publickey',
      max_sessions: 2000,
      ssh_cli: { Breakout.Sshd.Channel, [] },
      subsystems: [],
      quiet_mode: true,
      parallel_login: true,
      key_cb: Breakout.Sshd.KeyAuth
    ]

    {:ok, _ref} = :ssh.daemon(port, options)
  end

  def config(name) do
    Application.get_env :breakout_sshd, name
  end
end
