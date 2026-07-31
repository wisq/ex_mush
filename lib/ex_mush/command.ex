defmodule ExMUSH.Command do
  defmacro __using__(_opts) do
    quote do
      import ExMUSH.Command.Builder, only: [defcommand: 2]
      @before_compile ExMUSH.Command.Builder

      Module.register_attribute(__MODULE__, :command_list, accumulate: true)

      @command nil
      @aliases []
      @switches []
      @parser nil
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
            switches: @switches |> Map.new(fn sw -> {sw, String.to_atom(sw)} end),
            parser: @parser,
            execute: ref
          ]

          @command nil
          @aliases []
          @switches []
          @parser nil
        end

        def unquote(definition), unquote(block)
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
    [
      ExMUSH.Command.Basic,
      ExMUSH.Command.Look
    ]
    |> Enum.flat_map(& &1.__commands__())
  end

  def build(attrs) do
    struct!(Command, attrs)
  end

  def switch_map(%Command{name: cmd, switches: defined}, requested) do
    base = defined |> Map.new(fn {_name, key} -> {key, false} end)

    requested
    |> Enum.reduce_while({:ok, base}, fn req, {:ok, switches} ->
      case matching_switches(defined, String.downcase(req)) do
        [key] -> {:cont, {:ok, Map.put(switches, key, true)}}
        [] -> {:halt, {:error, {:unknown_switch, cmd, req}}}
        [_, _ | _] -> {:halt, {:error, {:ambiguous_switch, cmd, req}}}
      end
    end)
  end

  defp matching_switches(defined, requested) do
    case Map.fetch(defined, requested) do
      {:ok, key} ->
        [key]

      :error ->
        defined
        |> Enum.filter(fn {name, _key} -> String.starts_with?(name, requested) end)
        |> Enum.map(fn {_name, key} -> key end)
    end
  end
end
