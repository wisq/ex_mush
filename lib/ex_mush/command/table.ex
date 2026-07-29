defmodule ExMUSH.Command.Table do
  use GenServer

  alias ExMUSH.Command

  @ets __MODULE__.ETS

  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @impl true
  def init(_) do
    :ets.new(@ets, [:ordered_set, :protected, :named_table])

    Command.all_commands()
    |> Enum.flat_map(fn %Command{name: name, aliases: aliases} = command ->
      [name | aliases]
      |> Enum.map(fn key ->
        {key, command}
      end)
    end)
    |> then(&:ets.insert(@ets, &1))

    {:ok, nil, :hibernate}
  end

  def lookup(name) do
    name = String.downcase(name)

    case :ets.lookup(@ets, name) do
      [{^name, command}] -> {:ok, command}
      [] -> partial_match(name)
    end
  end

  defp partial_match(name) do
    case :ets.next_lookup(@ets, name) do
      {^name <> _ = match, [{match, command}]} ->
        # We found a partial match, but if the next ALSO matches, it's ambiguous.
        case :ets.next(@ets, match) do
          ^name <> _ -> {:error, {:ambiguous_command, name}}
          _ -> {:ok, command}
        end

      _ ->
        {:error, {:unknown_command, name}}
    end
  end
end
