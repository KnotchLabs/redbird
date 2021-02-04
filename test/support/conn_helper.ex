defmodule RedbirdTest.ConnHelper do
  @default_opts [store: :redis, key: "_session_key"]
  @secret String.duplicate("thoughtbot", 8)

  def sign_conn(conn, options \\ []) do
    conn.secret_key_base
    |> put_in(@secret)
    |> Plug.Session.call(sign_plug(options))
    |> Plug.Conn.fetch_session()
  end

  def sign_plug(options) do
    options =
      (options ++ @default_opts)
      |> Keyword.put(:encrypt, false)

    Plug.Session.init(options)
  end
end
