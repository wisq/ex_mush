defmodule ExMUSH.Commands.Teleport do
  require Logger
  use ExMUSH.Command
  alias ExMUSH.Context
  alias ExMUSH.World.Object
  alias ExMUSH.World.Matching

  @command "@teleport"
  # TODO: @switches ~w"list inside silent"
  @parser :two_args

  defcommand teleport(%Context{player: player}, _switches) do
    Object.tell(player, "Teleport where?")
  end

  defcommand teleport(%Context{player: player}, _switches, whatstr \\ "me", wherestr) do
    with {:ok, what} <- locate(:what, player, whatstr),
         {:ok, where} <- locate(:where, player, wherestr),
         :ok <- can_teleport(what, player),
         :ok <- can_teleport_to(what, where, player),
         {:ok, _} <- do_teleport(what, where) do
      if what.oid == player.oid do
        :silent
      else
        "Teleported."
      end
    else
      {:error, :what, :no_match} -> "I can't see that here."
      {:error, :what, :ambiguous_match} -> "I don't know which one you mean!"
      {:error, :where, :no_match} -> "I can't find that destination."
      {:error, :where, :ambiguous_match} -> "I don't know which destination you mean!"
      {:error, :not_that} -> "You don't have permission to teleport that."
      {:error, :not_there} -> "You don't have permission to teleport to that location."
      {:error, :exit_not_nearby} -> "That exit is too far away."
      {:error, :cannot_move_room} -> "You can't teleport rooms."
      {:error, :object_moved} -> "Someone just moved that -- try again."
      err -> unknown_error(err)
    end
    |> then(fn
      :silent -> :ok
      message when is_binary(message) -> Object.tell(player, message)
    end)
  end

  defp locate(:where, _player, "home"), do: {:ok, :home}

  defp locate(type, player, str) do
    case Matching.locate(player, str) do
      {:ok, %Object{} = match} -> {:ok, match}
      {:error, err} -> {:error, type, err}
    end
  end

  defp can_teleport(what, player) do
    cond do
      Object.controls?(player, what) -> :ok
      Object.controls?(player, what.location_oid) -> :ok
      true -> {:error, :not_that}
    end
  end

  defp can_teleport_to(_what, :home, _player), do: :ok

  defp can_teleport_to(what, %Object{type: :exit} = exit, player) do
    cond do
      Object.controls?(player, exit) -> :ok
      what.location_oid == exit.location_oid -> :ok
      true -> {:error, :exit_not_nearby}
    end
  end

  defp can_teleport_to(_what, where, player) do
    cond do
      Object.controls?(player, where) -> :ok
      :jump_ok in where.flags -> :ok
      true -> {:error, :not_there}
    end
  end

  defp do_teleport(what, :home), do: do_teleport(what, Object.home(what))

  defp do_teleport(what, %Object{type: :exit} = exit) do
    # TODO: This should trigger exit messages (once those are a thing).
    #
    # We don't need to check exit source because `can_teleport_to` already did
    # that, but we should check to make sure it hasn't moved in the interim.
    Object.move(what, what.location_oid, exit.link_oid)
  end

  defp do_teleport(what, where), do: Object.move(what, where)

  defp unknown_error(err) do
    Logger.warning("Unknown error in @teleport: #{inspect(err)}")
    "Sorry, an unknown error occurred.  Check server logs."
  end
end
