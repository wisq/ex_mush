import Config

config :ex_mush, ExMUSH.DB.Repo,
  database: "ex_mush_test",
  hostname: "localhost",
  port: "5432",
  pool: Ecto.Adapters.SQL.Sandbox

config :ex_mush,
  telnet_ip: "127.0.0.1",
  telnet_port: 0

config :logger, :console, format: "$time $metadata[$level] $message\n"
config :logger, level: :warning
