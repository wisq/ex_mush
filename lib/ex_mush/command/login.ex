defmodule ExMUSH.Command.Login do
  import NimbleParsec
  alias ExMUSH.World

  @motd ~S"""
    
     Welcome to ...
                      _____    ___  ____   _ _____ _   _ 
                     |  ___|   |  \/  | | | /  ___| | | |
                     | |____  _| .  . | | | \ `--.| |_| |
                     |  __\ \/ / |\/| | | | |`--. \  _  |
                     | |___>  <| |  | | |_| /\__/ / | | |
                     \____/_/\_\_|  |_/\___/\____/\_| |_/
    
                        ... the actor-model MUSH server nobody asked for.
     --------------------------------------------------------------------
     Use create <name> <password> to create a character.
     Use connect <name> <password> to connect to your existing character.
     Use QUIT to logout.
     Use the WHO command to find out who is online currently.
     --------------------------------------------------------------------
  """
  def motd, do: @motd

  space = ascii_string([?\s], min: 1)
  command_1_7 = ascii_string([?A..?Z, ?a..?z], min: 1, max: 7)
  username_bare = utf8_string([{:not, ?"}, {:not, ?\s}], min: 1)

  username_quoted =
    ignore(string(~s{"}))
    |> utf8_string([{:not, ?"}], min: 1)
    |> ignore(string(~s{"}))

  username = choice([username_bare, username_quoted])
  connect_or_create = command_1_7 |> ignore(space) |> concat(username) |> ignore(space)

  who = string("WHO") |> eos()

  defparsecp(
    :login_command,
    choice([
      who,
      connect_or_create
    ])
  )

  def parse(str) do
    case str |> String.trim() |> login_command() do
      {:ok, ["WHO"], "", _, _, _} ->
        {:ok, :who}

      {:ok, [cmd, username], password, _, _, _} ->
        cmd = String.downcase(cmd)

        cond do
          # "c" deliberately maps to "connect" and not "create"
          String.starts_with?("connect", cmd) -> {:ok, {:connect, username, password}}
          String.starts_with?("create", cmd) -> {:ok, {:create, username, password}}
          true -> {:error, :unknown_command}
        end

      {:error, _, _, _, _, _} ->
        {:error, :unknown_command}
    end
  end

  def execute(:who, out), do: out.("WHO: Not implemented yet.")

  def execute({:create, _, _}, out), do: out.("CREATE: Not implemented yet.")

  def execute({:connect, user, pass}, out) do
    case World.Login.connect(user, pass) do
      {:error, :no_match} ->
        out.("There is no player with that name.")

      {:error, :wrong_password} ->
        out.("That is not the correct password.")

      {:ok, oid} ->
        out.("*** Connected ***")
        {:connected, oid}
    end
  end
end
