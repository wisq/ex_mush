defmodule ExMUSH.World.ObjectRegistry do
  def child_spec(opts) do
    Registry.child_spec(opts ++ [name: __MODULE__, keys: :unique])
  end

  def register(obj_id, value) when is_integer(obj_id) do
    Registry.register(__MODULE__, obj_id, value)
  end

  def lookup(obj_id) do
    case Registry.lookup(__MODULE__, obj_id) do
      [{pid, value}] -> {pid, value}
      [] -> nil
    end
  end
end
