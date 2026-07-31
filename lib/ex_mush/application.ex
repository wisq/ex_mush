defmodule ExMUSH.Application do
  use Application
  require Logger

  def start(_type, _args) do
    children = [
      ExMUSH.DB.Repo,
      ExMUSH.World.Supervisor,
      ExMUSH.Command.Table,
      ExMUSH.Action.Supervisor,
      ExMUSH.ActionList.Supervisor,
      ExMUSH.Network.SessionRegistry,
      ExMUSH.Network.SessionSupervisor,
      {ThousandIsland, telnet_options()}
    ]

    opts = [
      strategy: :one_for_one,
      name: ExMUSH.Supervisor
    ]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      {:ok, {ip, port}} = ThousandIsland.listener_info(ExMUSH.Network.TelnetSupervisor)
      ip = :inet.ntoa(ip)
      Logger.info("ExMUSH started.  Listening for telnet connections on #{ip}:#{port}.")

      {:ok, pid}
    end
  end

  defp telnet_options do
    [
      port: telnet_port(),
      transport_options: [ip: telnet_ip()],
      handler_module: ExMUSH.Network.Telnet,
      read_timeout: :infinity,
      supervisor_options: [name: ExMUSH.Network.TelnetSupervisor]
    ]
  end

  @appname :ex_mush

  defp telnet_port, do: Application.get_env(@appname, :telnet_port, 4202)
  defp telnet_ip, do: Application.get_env(@appname, :telnet_ip, "127.0.0.1") |> inet_aton()

  defp inet_aton(tuple) when is_tuple(tuple) do
    case :inet.is_ip_address(tuple) do
      true -> tuple
      false -> raise "Not an IP address: #{inspect(tuple)}"
    end
  end

  defp inet_aton(str) when is_binary(str) do
    case str |> String.to_charlist() |> :inet.parse_address() do
      {:ok, addr} when is_tuple(addr) -> addr
      {:error, :einval} -> raise "Not an IP address: #{inspect(str)}"
    end
  end
end
