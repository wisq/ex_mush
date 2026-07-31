defmodule ExMUSH.Command.Indexer do
  def find_modules do
    Path.join([
      Path.dirname(__DIR__),
      "commands",
      "**",
      "*.ex"
    ])
    |> Path.wildcard()
    |> Enum.flat_map(&read_modules/1)
  end

  defp read_modules(file) do
    File.stream!(file)
    |> Enum.filter(fn
      "defmodule ExMUSH.Commands." <> _ -> true
      _ -> false
    end)
    |> Enum.map(fn line ->
      String.split(line)
      |> Enum.at(1)
      |> then(&"Elixir.#{&1}")
      |> String.to_atom()
    end)
  end
end
