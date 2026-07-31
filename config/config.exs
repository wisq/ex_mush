import Config

config :ex_mush, ecto_repos: [ExMUSH.DB.Repo]

import_config "#{Mix.env()}.exs"
