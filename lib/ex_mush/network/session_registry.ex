defmodule ExMUSH.Network.SessionRegistry do
  import ExMUSH
  alias ExMUSH.Network.Session

  def child_spec(opts) do
    Registry.child_spec(opts ++ [name: __MODULE__, keys: :duplicate])
  end

  def register(player_oid, %{} = conn_info) when is_object_id(player_oid) do
    Registry.register(__MODULE__, player_oid, conn_info)
  end

  def connected?(player_oid) do
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

  def notify(player_oid, iodata) when is_object_id(player_oid) do
    Registry.dispatch(__MODULE__, player_oid, fn matches ->
      matches
      |> Enum.each(fn {pid, _value} ->
        Session.output(pid, iodata)
      end)
    end)
  end
end
