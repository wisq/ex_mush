import Config

config :ex_mush, ecto_repos: [ExMUSH.DB.Repo]

config :ex_mush, ExMUSH.DB.Repo,
  database: "ex_mush",
  hostname: "localhost",
  port: "5432"
