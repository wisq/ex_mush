defmodule ExMUSH.Network.SessionRegistry do
  import ExMUSH
  alias ExMUSH.Network.Session

  def child_spec(opts) do
    Registry.child_spec(opts ++ [name: __MODULE__, keys: :duplicate])
  end

  def register(player_oid, %{} = conn_info) when is_object_id(player_oid) do
    Registry.register(__MODULE__, player_oid, conn_info)
  end

  def broadcast(player_oid, iodata) when is_object_id(player_oid) do
    Registry.lookup(__MODULE__, player_oid)
    |> Enum.each(fn {pid, _value} ->
      Session.output(pid, iodata)
    end)
  end
end
