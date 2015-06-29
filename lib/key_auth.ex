# http://www.erlang.org/doc/man/ssh_server_key_api.html
defmodule Breakout.Sshd.KeyAuth do
  alias Breakout.Sshd.Utils

  # Return
  # {:ok, Key}
  # {:error, "Failed something"}
  def host_key(alg, daemon_options) do
    IO.puts "alg #{inspect alg}"

    dir = to_string :proplists.get_value(:system_dir, daemon_options)

    file = case alg do
      :"ssh-dss" ->
        "ssh_host_dsa_key"
      :"ssh-rsa" ->
        "ssh_host_rsa_key"
    end

    load_key(dir <> "/" <> file)
  end

  # key DSA/RSA public key
  # user string
  # bool
  def is_auth_key(key, user, daemon_options) do
    [type, base64 | _] = String.split :pubkey_ssh.encode([{key, []}], :openssh_public_key), " "
    data = :base64.mime_decode(base64)
    md5 = Utils.bin_to_hex :crypto.hash(:md5, data)

    IO.puts "key type: #{type} md5: #{inspect md5} user: #{inspect user} opts #{inspect daemon_options}"
    md5 == "1b:7:46:c1:7:7:93:50:cb:9b:25:1c:3d:a5:49:98"
  end

  def load_key(path) do
    case File.read(path) do
      {:ok, content} ->
        [entry] = :public_key.pem_decode(content)
        {:ok, :public_key.pem_entry_decode(entry)}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
