defmodule Redbird.Crypto do
  def sign_key(key, conn, opts \\ []) do
    conn
    |> key_base()
    |> Plug.Crypto.sign(signing_salt(), key, opts)
  end

  def verify_key(key, conn, opts \\ []) do
    conn
    |> key_base()
    |> Plug.Crypto.verify(signing_salt(), key, opts)
  end

  def safe_binary_to_term(b, opts \\ []) when is_binary(b) do
    Plug.Crypto.non_executable_binary_to_term(b, opts)
  end

  # TODO: Allow either conn.secret_key_base or Application.get_env ???
  defp key_base(conn) do
    conn.secret_key_base
  end

  @default_signing_salt "redbird"
  defp signing_salt do
    Application.get_env(:redbird, :signing_salt, @default_signing_salt)
  end
end
