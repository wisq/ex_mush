defmodule ExMUSH.Network.Telnet.IAC do
  @iac 255
  @subopt_begin 250
  @subopt_end 240

  @naws 31
  @terminal_type 24
  @charset 42

  @negotiation [
    will: 251,
    wont: 252,
    do: 253,
    dont: 254
  ]

  @capabilities [
    naws: @naws,
    terminal_type: @terminal_type,
    transmit_binary: 0,
    charset: @charset,
    echo: 1,
    suppress_go_ahead: 3
  ]

  @commands [
    noop: 241,
    interrupt: 244,
    abort: 245,
    are_you_there: 246,
    erase_char: 247,
    erase_line: 248
  ]

  @atoms_to_bytes [
                    [iac: @iac],
                    @negotiation,
                    @capabilities,
                    @commands
                  ]
                  |> Enum.reduce(&Kernel.++/2)
                  |> Map.new()

  @bytes_to_atoms Map.new(@atoms_to_bytes, fn {k, v} -> {v, k} end)

  def to_bytes(atoms) do
    atoms
    |> Enum.map(fn cmd ->
      byte = Map.fetch!(@atoms_to_bytes, cmd)
      <<byte>>
    end)
  end

  def request_terminal_type do
    <<@iac, @subopt_begin, @terminal_type, 1, @iac, @subopt_end>>
  end

  def offer_utf8_charset do
    <<@iac, @subopt_begin, @charset, 1, 1, "UTF-8", @iac, @subopt_end>>
  end

  def parse(<<@iac, @iac, rest::binary>>), do: {:data, <<@iac>>, rest}

  @command_bytes Keyword.values(@commands)
  def parse(<<@iac, byte, rest::binary>>) when byte in @command_bytes do
    atom = Map.fetch!(@bytes_to_atoms, byte)
    {:command, [:iac, atom], rest}
  end

  @negotiation_bytes Keyword.values(@negotiation)
  @capability_bytes Keyword.values(@capabilities)
  def parse(<<@iac, n_byte, c_byte, rest::binary>>)
      when n_byte in @negotiation_bytes and c_byte in @capability_bytes do
    n_atom = Map.fetch!(@bytes_to_atoms, n_byte)
    c_atom = Map.fetch!(@bytes_to_atoms, c_byte)
    {:command, [:iac, n_atom, c_atom], rest}
  end

  def parse(<<@iac, @subopt_begin, rest::binary>>) do
    case read_subopt(rest) do
      {:complete, subopt, rest} ->
        {:command, [:iac, :subopt | parse_subopt(subopt)], rest}

      :incomplete ->
        :partial_command
    end
  end

  # We can't just assume any unknown command is incomplete, since then we'd
  # be buffering IAC commands forever.
  #
  # Instead, we only match known incomplete commands:
  #  - IAC with nothing after it
  def parse(<<@iac>>), do: :partial_command
  #  - IAC negotiation with no capability
  def parse(<<@iac, n_byte>>) when n_byte in @negotiation_bytes, do: :partial_command

  defp parse_subopt(<<@naws, width::integer-size(16), height::integer-size(16)>>) do
    [:naws, {width, height}]
  end

  defp parse_subopt(<<@terminal_type, 0, type::binary>>) do
    [:terminal_type, type]
  end

  defp parse_subopt(<<@charset, 2, encoding::binary>>) do
    [:charset, {:accepted, encoding}]
  end

  defp parse_subopt(<<@charset, 3, encoding::binary>>) do
    [:charset, {:rejected, encoding}]
  end

  defp read_subopt(bytes, buffer \\ []) do
    case :binary.match(bytes, <<@iac>>) do
      :nomatch ->
        :incomplete

      {index, 1} ->
        <<chunk::binary-size(^index), match::binary>> = bytes

        case match do
          <<@iac, @iac, rest::binary>> ->
            read_subopt(rest, [<<@iac>>, chunk | buffer])

          <<@iac, @subopt_end, rest::binary>> ->
            {
              :complete,
              [chunk | buffer] |> Enum.reverse() |> :erlang.iolist_to_binary(),
              rest
            }
        end
    end
  end
end
