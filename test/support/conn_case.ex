defmodule Redbird.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Plug.Test
      import Redbird.ConnCase
    end
  end

  @default_opts [store: :redis, key: "_session_key"]
  @secret String.duplicate("thoughtbot", 8)

  def sign_conn(conn, options \\ []) do
    put_in(conn.secret_key_base, @secret)
    |> Plug.Session.call(sign_plug(options))
    |> Plug.Conn.fetch_session()
  end

  def sign_plug(options) do
    (options ++ @default_opts)
    |> Keyword.put(:encrypt, false)
    |> Plug.Session.init()
  end
end
