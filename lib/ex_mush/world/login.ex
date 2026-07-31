defmodule ExMUSH.World.Login do
  import ExMUSH
  alias ExMUSH.ObjectID
  alias ExMUSH.World.Object
  alias ExMUSH.World.ObjectDirectory

  def connect(username, password) do
    with {:ok, oid} <- find_player(username),
         :ok <- check_password(oid, password) do
      {:ok, oid}
    end
  end

  defp find_player("#" <> _ = idstr) do
    with {:ok, oid} <- ObjectID.parse(idstr),
         {:ok, %Object{type: :player}} <- Object.fetch(oid) do
      {:ok, oid}
    end
  end

  defp find_player(name), do: ObjectDirectory.match_player_oid(name, :exact)

  defp check_password(oid, password) when is_object_id(oid) do
    case Object.attribute(oid, "XYXXY") do
      %{value: v} -> check_legacy_crypt(v, password)
      nil -> {:error, :wrong_password}
    end
  end

  defp check_legacy_crypt(<<"2:sha512:", salt::binary-size(2), rest::binary>>, password) do
    [hash, _] = String.split(rest, ":", parts: 2)

    case :crypto.hash(:sha512, salt <> password) |> Base.encode16(case: :lower) do
      ^hash -> :ok
      _ -> {:error, :wrong_password}
    end
  end
end
