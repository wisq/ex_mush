defmodule ExMUSH.Network.SessionRegistry do
  alias ExMUSH.Network.Session
  alias ExMUSH.ObjectID, as: OID

  def child_spec(opts) do
    Registry.child_spec(opts ++ [name: __MODULE__, keys: :duplicate])
  end

  def register(%OID{} = player_oid, %{} = conn_info) do
    Registry.register(__MODULE__, player_oid, conn_info)
  end

  def unregister(%OID{} = player_oid) do
    Registry.unregister(__MODULE__, player_oid)
  end

  def connected?(%OID{} = player_oid) do
    case Registry.lookup(__MODULE__, player_oid) do
      [] -> false
      [_ | _] -> true
    end
  end

  def broadcast(iodata) do
    try do
      Registry.select(__MODULE__, [{{:"$1", :"$2", :_}, [], [:"$2"]}])
    rescue
      ArgumentError -> []
    end
    |> Enum.uniq()
    |> Enum.each(fn pid ->
      Session.output(pid, iodata)
    end)
  end

  def notify(%OID{} = player_oid, iodata) do
    Registry.dispatch(__MODULE__, player_oid, fn matches ->
      matches
      |> Enum.each(fn {pid, _value} ->
        Session.output(pid, iodata)
      end)
    end)
  end
end
