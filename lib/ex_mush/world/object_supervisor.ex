defmodule ExMUSH.World.ObjectSupervisor do
  use DynamicSupervisor

  alias ExMUSH.World.Object
  alias ExMUSH.World.ObjectRegistry

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def ensure_started(obj_id) do
    case ObjectRegistry.lookup(obj_id) do
      {pid, value} -> {:ok, pid, value}
      nil -> start_object(obj_id)
    end
  end

  defp start_object(obj_id) do
    case DynamicSupervisor.start_child(__MODULE__, {Object, obj_id}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_registered, pid}} -> {:ok, pid}
      {:error, _} = err -> err
    end
    |> then(fn
      {:ok, pid} ->
        {^pid, value} = ObjectRegistry.lookup(obj_id)
        {:ok, pid, value}

      {:error, _} = err ->
        err
    end)
  end
end
