defmodule Breakout.Sshd.Utils do
  def bin_to_hex(<<n, rest :: binary>>) do
    hex = String.downcase(to_string(:erlang.integer_to_list(n, 16)))

    case rest do
      "" ->
        hex
      _ ->
        hex <> ":" <> bin_to_hex(rest)
    end
  end
end
