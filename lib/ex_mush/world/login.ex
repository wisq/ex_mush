defmodule ExMUSH.World.Login do
  alias ExMUSH.World.Object

  def connect(username, password) do
    with {:ok, %Object{} = player} <- match_user(username),
         :ok <- check_password(player, password) do
      {:ok, player}
    end
  end

  defp match_user(username) do
    {:error, :login_failed}
  end

  defp check_password(player, password) do
    {:error, :login_failed}
  end
end
