defmodule ExMUSH.World.Object.Flag do
  @enforce_keys [:key, :name]
  defstruct(
    key: nil,
    name: nil,
    letter: nil,
    persisted: true
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
    %Flag{key: :connected, name: "CONNECTED", letter: ?c, persisted: false},
    %Flag{key: :no_command, name: "NO_COMMAND", letter: ?n},
    %Flag{key: :myopic, name: "MYOPIC", letter: ?m},
    %Flag{key: :dark, name: "DARK", letter: ?D},
    %Flag{key: :light, name: "LIGHT", letter: ?l},
    %Flag{key: :jump_ok, name: "JUMP_OK", letter: ?J},
    %Flag{key: :link_ok, name: "LINK_OK", letter: ?L}
  ]

  def db_flag_keys do
    @flags
    |> Enum.filter(& &1.persisted)
    |> MapSet.new(& &1.key)
  end

  def db_flags_by_name do
    @flags
    |> Enum.filter(& &1.persisted)
    |> Map.new(&{&1.name, &1})
  end

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
