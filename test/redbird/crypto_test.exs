defmodule Redbird.CryptoTest do
  use Redbird.ConnCase, async: true

  alias Redbird.Crypto

  describe "sign_key/3" do
    test "signs the key using the conn secret key base and a signing salt" do
      conn = signed_conn()
      key = "somerediskey"

      actual = Crypto.sign_key(conn, key)

      refute actual =~ key
      assert {:ok, ^key} = Crypto.verify_key(conn, actual)
    end
  end

  describe "verify_key/3" do
    test "verifies keys signed using the secret key base and signing salt" do
      conn = signed_conn()
      key = "somerediskey"
      signed_key = Crypto.sign_key(conn, key)

      assert {:ok, ^key} = Crypto.verify_key(conn, signed_key)
    end

    test "invalidates keys signed using another secret key base" do
      conn = signed_conn()
      key = "somerediskey"
      signed_key = Crypto.sign_key(conn, key)
      another_conn = signed_conn()

      assert {:error, :invalid} = Crypto.verify_key(another_conn, signed_key)
    end

    test "invalidates keys that have been tampered with" do
      conn = signed_conn()
      key = "somerediskey"
      signed_key = Crypto.sign_key(conn, key)
      tampered_key = tamper_with_key(signed_key)

      assert {:error, :invalid} = Crypto.verify_key(conn, tampered_key)
    end
  end

  describe "safe_binary_to_term/1" do
    test "translates a binary to terms" do
      expected = %{hello: "world"}
      binary = :erlang.term_to_binary(expected)

      actual = Crypto.safe_binary_to_term(binary)

      assert expected == actual
    end

    test "safely translates what would otherwise be unsafe terms" do
      expected = fn -> raise "Elixir go boom!" end
      binary = :erlang.term_to_binary(expected)

      assert_raise ArgumentError, fn ->
        Crypto.safe_binary_to_term(binary)
      end
    end
  end

  defp tamper_with_key(key) do
    [first | other] = String.graphemes(key)
    Enum.join([other, first])
  end
end
