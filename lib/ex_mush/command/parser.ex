defmodule ExMUSH.Command.Parser do
  import NimbleParsec
  alias ExMUSH.Command

  space = ascii_string([?\s], min: 1) |> ignore()
  command_name = ascii_string([?@, ?A..?Z, ?a..?z], min: 1, max: 20)
  switch = string("/") |> ignore() |> ascii_string([?A..?Z, ?a..?z], min: 1, max: 10)

  defparsecp(
    :parse_command,
    command_name
    |> repeat(switch)
    |> choice([space, eos()])
  )

  def parse(line) do
    with {:ok, [cmdname | switch_strs], argstr, _, _, _} <- parse_command(line),
         {:ok, command} <- Command.Table.lookup(cmdname),
         args <- parse_args(command.parser, argstr),
         {:ok, switch_map} <- Command.switch_map(command, switch_strs) do
      {:ok, %Command.Prepared{command: command, switches: switch_map, args: args}}
    else
      {:error, _, _, _, _, _} -> {:error, :no_match}
      {:error, _} = err -> err
    end
  end

  defp parse_args(_, ""), do: []

  defp parse_args(:one_arg, argstr), do: [argstr]
  defp parse_args(:two_args, argstr), do: argstr |> String.split("=", parts: 2)
end
