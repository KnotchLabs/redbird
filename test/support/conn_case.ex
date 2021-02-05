defmodule Redbird.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Plug.Test
      import Redbird.ConnCase
    end
  end

  @default_opts [store: :redis, key: "_session_key"]

  def signed_conn do
    :get |> Plug.Test.conn("/") |> sign_conn()
  end

  def sign_conn(conn, options \\ []) do
    put_in(conn.secret_key_base, generate_secret())
    |> Plug.Session.call(sign_plug(options))
    |> Plug.Conn.fetch_session()
  end

  def sign_plug(options) do
    (options ++ @default_opts)
    |> Keyword.put(:encrypt, false)
    |> Plug.Session.init()
  end

  def generate_secret(length \\ 10) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64
    |> binary_part(0, length)
  end
end
