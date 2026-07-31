defmodule ExMUSH.ObjectID do
  @enforce_keys [:id]
  defstruct(
    id: nil,
    ctime: nil
  )

  alias __MODULE__, as: OID

  def new(id) when is_integer(id), do: %OID{id: id}

  def new(id, ctime) when is_integer(id) and is_integer(ctime),
    do: %OID{id: id, ctime: ctime}

  def from_db(nil), do: new(-1)
  def from_db(id) when is_integer(id), do: new(id)

  def to_db(%OID{id: -1}), do: nil
  def to_db(%OID{id: id}), do: id

  def parse("#" <> idstr) do
    parsed =
      idstr
      |> String.split(":", parts: 2)
      |> Enum.map(fn str ->
        case Integer.parse(str) do
          {int, ""} -> int
          _ -> :error
        end
      end)

    if :error in parsed do
      :error
    else
      case parsed do
        [id] -> {:ok, %OID{id: id}}
        [id, _] when id < 0 -> :error
        [id, ctime] -> {:ok, %OID{id: id, ctime: ctime}}
      end
    end
  end

  def parse(str) when is_binary(str), do: :error

  defimpl Inspect do
    alias ExMUSH.ObjectID, as: OID

    def inspect(%OID{id: id}, opts) when id < 0, do: {"~o'##{id}'", opts}
    def inspect(%OID{id: id, ctime: nil}, opts), do: {"~o'##{id}'", opts}
    def inspect(%OID{id: id, ctime: ctime}, opts), do: {"~o'##{id}:#{ctime}'", opts}
  end

  defimpl String.Chars do
    alias ExMUSH.ObjectID, as: OID

    def to_string(%OID{id: id}) when id < 0, do: "##{id}"
    def to_string(%OID{id: id, ctime: nil}), do: "##{id}"
    def to_string(%OID{id: id, ctime: ctime}), do: "##{id}:#{ctime}"
  end
end
