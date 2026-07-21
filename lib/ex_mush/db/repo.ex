defmodule ExMUSH.DB.Repo do
  use Ecto.Repo,
    otp_app: :ex_mush,
    adapter: Ecto.Adapters.Postgres
end
