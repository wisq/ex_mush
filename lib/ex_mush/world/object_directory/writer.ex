defmodule ExMUSH.World.ObjectDirectory.Writer do
  use GenServer
  import ExMUSH
  alias ExMUSH.World.Object
  alias ExMUSH.DB

  # Queue a flush in one second after receiving a change.
  @flush_delay 1000

  defmodule State do
    @enforce_keys [:to_flush, :flush_pending]
    defstruct(@enforce_keys)

    def empty, do: %State{to_flush: MapSet.new(), flush_pending: false}
  end

  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def write(oid) when is_object_id(oid) do
    GenServer.cast(__MODULE__, {:write, oid})
  end

  @impl true
  def init(_) do
    {:ok, State.empty()}
  end

  @impl true
  def handle_cast({:write, oid}, %State{} = state) when is_object_id(oid) do
    {:noreply,
     %State{state | to_flush: MapSet.put(state.to_flush, oid)}
     |> queue_flush()}
  end

  @impl true
  def handle_info(:flush, %State{to_flush: to_flush}) do
    to_flush
    |> Enum.map(&Object.get/1)
    |> Enum.map(&Object.to_db/1)
    |> then(fn records ->
      DB.Repo.insert_all(DB.Object, records,
        conflict_target: :id,
        on_conflict: :replace_all
      )
    end)

    {:noreply, State.empty()}
  end

  defp queue_flush(%State{flush_pending: true} = state), do: state

  defp queue_flush(%State{flush_pending: false} = state) do
    Process.send_after(self(), :flush, @flush_delay)
    %State{state | flush_pending: true}
  end
end
