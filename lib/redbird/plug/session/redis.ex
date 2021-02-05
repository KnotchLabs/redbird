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
    with {:ok, _verified_key} <- Crypto.verify_key(conn, namespaced_key),
         value when is_binary(value) <- get(namespaced_key) do
      {namespaced_key, Crypto.safe_binary_to_term(value)}
    else
      _ -> {nil, %{}}
    end
  end

  def put(conn, nil, data, init_options) do
    put(conn, add_namespace(generate_random_key()), data, init_options)
  end

  def put(conn, namespaced_key, data, init_options) do
    set_key_with_retries(
      Crypto.sign_key(conn, namespaced_key),
      :erlang.term_to_binary(data),
      session_expiration(init_options),
      1
    )
  end

  def delete(conn, redis_key, _init_options) do
    if :ok == conn |> Crypto.verify_key(redis_key) |> elem(0),
      do: del(redis_key)
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

  defp add_namespace(key) do
    namespace() <> key
  end

  @default_namespace "redbird_session_"
  def namespace do
    Application.get_env(:redbird, :key_namespace, @default_namespace)
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
