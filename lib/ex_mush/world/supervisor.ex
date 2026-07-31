defmodule ExMUSH.World.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    [
      ExMUSH.World.ObjectDirectory,
      ExMUSH.World.ObjectDirectory.Writer,
      ExMUSH.World.ObjectRegistry,
      ExMUSH.World.ObjectSupervisor
    ]
    |> Supervisor.init(strategy: :one_for_all)
  end
end
