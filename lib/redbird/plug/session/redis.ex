defmodule Plug.Session.REDIS do
  import Redbird.Redis
  alias Redbird.Crypto

  @moduledoc """
  Stores the session in a redis store.
  """

  @behaviour Plug.Session.Store

  @max_session_time 86_164 * 30

  def init(opts) do
    opts
  end

  def get(conn, namespaced_key, _init_options) do
    with key when is_binary(key) <- remove_namespace(namespaced_key),
         {:ok, _verified_key} <- Crypto.verify_key(key, conn),
         value when is_binary(value) <- get(namespaced_key) do
      {namespaced_key, Crypto.safe_binary_to_term(value)}
    else
      _ -> {nil, %{}}
    end
  end

  # TODO: It looks like it respects the raw key if one is given
  def put(conn, nil, data, init_options) do
    IO.inspect(nil, label: "#{__MODULE__} put with nil")
    put(conn, prepare_key(conn), data, init_options)
  end

  def put(_conn, key, data, init_options) do
    IO.inspect(key, label: "#{__MODULE__} put with key")
    set_key_with_retries(key, :erlang.term_to_binary(data), session_expiration(init_options), 1)
  end

  def delete(conn, redis_key, _init_options) do
    if deletable_key?(redis_key, conn), do: del(redis_key)

    :ok
  end

  defp set_key_with_retries(key, value, seconds, counter) do
    case setex(%{key: key, value: value, seconds: seconds}) do
      :ok ->
        key

      response ->
        if counter > 5 do
          Redbird.RedisError.raise(error: response, key: key)
        else
          set_key_with_retries(key, value, seconds, counter + 1)
        end
    end
  end

  defp remove_namespace(key) do
    key |> String.split(namespace(), parts: 2) |> tl() |> hd()
  end

  @default_namespace "redbird_session_"
  def namespace do
    Application.get_env(:redbird, :key_namespace, @default_namespace)
  end

  defp prepare_key(conn) do
    namespace() <> Crypto.sign_key(generate_random_key(), conn)
  end

  defp deletable_key?(key, conn) do
    key
    |> remove_namespace()
    |> Crypto.verify_key(conn)
    |> elem(0)
    |> Kernel.==(:ok)
  end

  defp generate_random_key do
    :crypto.strong_rand_bytes(96) |> Base.encode64()
  end

  defp session_expiration(opts) do
    case opts[:expiration_in_seconds] do
      seconds when is_integer(seconds) -> seconds
      _ -> @max_session_time
    end
  end
end

defmodule Redbird.RedisError do
  defexception [:message]
  @base_message "Redbird was unable to store the session in redis."

  def raise(error: error, key: key) do
    message = "#{@base_message} Redis Error: #{error} key: #{key}"
    raise __MODULE__, message
  end

  def exception(message) do
    %__MODULE__{message: message}
  end
end
