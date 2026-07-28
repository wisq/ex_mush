defmodule ExMUSH.Command do
  defmacro __using__(_opts) do
    quote do
      import ExMUSH.Command.Builder, only: [defcommand: 2]
      @before_compile ExMUSH.Command.Builder

      Module.register_attribute(__MODULE__, :command_list, accumulate: true)
    end
  end

  defmodule Builder do
    defmacro defcommand({fname, _, _} = definition, block) do
      quote do
        if @command != nil do
          ref = {__MODULE__, unquote(fname)}

          @command_list [
            name: @command,
            aliases: @aliases,
            switches: @switches,
            parser: @parser,
            execute: ref
          ]

          @command nil
          @aliases []
          @switches []
          @parser nil
        end

        def unquote(definition), do: unquote(block)
      end
    end

    defmacro __before_compile__(_env) do
      quote do
        def __commands__, do: @command_list |> Enum.map(&ExMUSH.Command.build/1)
      end
    end
  end

  alias __MODULE__

  @enforce_keys [:name, :aliases, :switches, :parser, :execute]
  defstruct(@enforce_keys)

  def all_commands do
    [ExMUSH.Command.Basic]
    |> Enum.flat_map(& &1.__commands__())
  end

  def build(attrs) do
    struct!(Command, attrs)
  end
end
