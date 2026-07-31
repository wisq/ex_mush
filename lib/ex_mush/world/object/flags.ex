defmodule ExMUSH.World.Object.Flag do
  @enforce_keys [:key, :name]
  defstruct(
    key: nil,
    name: nil,
    letter: nil
  )
end

defmodule ExMUSH.World.Object.Flags do
  alias ExMUSH.World.Object
  alias ExMUSH.World.Object.Flag

  @type_flags %{
    room: ?R,
    exit: ?E,
    player: ?P,
    thing: ?T,
    garbage: ?G
  }

  @flags [
    %Flag{key: :wizard, name: "WIZARD", letter: ?W},
    %Flag{key: :royalty, name: "ROYALTY", letter: ?r},
    %Flag{key: :myopic, name: "MYOPIC", letter: ?m},
    %Flag{key: :dark, name: "DARK", letter: ?D},
    %Flag{key: :light, name: "LIGHT", letter: ?l}
  ]

  def flag_keys, do: @flags |> Enum.map(& &1.key)

  def letters(%Object{} = this) do
    type_letter = Map.fetch!(@type_flags, this.type)

    flag_letters =
      @flags
      |> Enum.filter(fn
        %Flag{letter: nil} -> false
        %Flag{key: k} -> k in this.flags
      end)
      |> Enum.map(& &1.letter)

    [type_letter | flag_letters]
    |> to_string()
  end
end
