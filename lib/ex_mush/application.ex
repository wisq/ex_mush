defmodule ExMUSH.Application do
  use Application

  def start(_type, _args) do
    [
      ExMUSH.DB.Repo,
      ExMUSH.World.ObjectDirectory,
      ExMUSH.World.ObjectRegistry,
      ExMUSH.World.ObjectSupervisor,
      ExMUSH.Network.SessionSupervisor,
      {ThousandIsland, telnet_options()}
    ]
    |> Supervisor.start_link(
      strategy: :one_for_one,
      name: ExMUSH.Supervisor
    )
  end

  defp telnet_options do
    [port: 4202, handler_module: ExMUSH.Network.Telnet]
  end
end
