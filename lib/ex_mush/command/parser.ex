defmodule ExMUSH.Command.Parser do
  import NimbleParsec
  alias ExMUSH.Command
  alias ExMUSH.Action

  space = ascii_string([?\s], min: 1) |> ignore()
  command_name = ascii_string([?@, ?A..?Z, ?a..?z], min: 1, max: 20)
  switch = string("/") |> ignore() |> ascii_string([?A..?Z, ?a..?z], min: 1, max: 10)

  command_prefix =
    [?", ?:, ?;, ?\\]
    |> Enum.map(fn c -> string(<<c>>) end)
    |> choice()

  defparsecp(
    :parse_command,
    choice([
      command_name |> repeat(switch) |> choice([space, eos()]),
      command_prefix
    ])
  )

  def parse(line) do
    with {:ok, [cmdname | switch_strs], argstr, _, _, _} <- parse_command(line),
         {:ok, command} <- Command.Table.lookup(cmdname),
         args <- parse_args(command.parser, argstr),
         {:ok, switch_map} <- Command.switch_map(command, switch_strs) do
      %Action{command: command, switches: switch_map, args: args}
    else
      _ -> %Action{command: Command.Unknown.command(), switches: %{}, args: [line]}
    end
  end

  defp parse_args(_, ""), do: []

  defp parse_args(:one_arg, argstr), do: [argstr]
  defp parse_args(:two_args, argstr), do: argstr |> String.split("=", parts: 2)
end
