defmodule ExMUSH.Network.Telnet.IAC do
  @iac 255
  @subopt_begin 250
  @subopt_end 240

  @naws 31
  @terminal_type 24
  @charset 42

  @negotiation %{
    will: 251,
    wont: 252,
    do: 253,
    dont: 254
  }

  @capabilities %{
    naws: @naws,
    terminal_type: @terminal_type,
    transmit_binary: 0,
    charset: @charset,
    echo: 1,
    suppress_go_ahead: 3,
    # Used in ctrl-C, ctrl-\, ctrl-Z
    timing_mark: 6
  }

  @commands %{
    end_of_file: 236,
    suspend: 237,
    abort_process: 238,
    end_of_record: 239,
    noop: 241,
    break: 243,
    interrupt: 244,
    abort_output: 245,
    are_you_there: 246,
    erase_char: 247,
    erase_line: 248,
    go_ahead: 249
  }

  @command_bytes Map.values(@commands)
  @negotiation_atoms Map.keys(@negotiation)
  @negotiation_bytes Map.values(@negotiation)
  @capability_atoms Map.keys(@capabilities)

  @command_bytes_to_atoms Map.new(@commands, fn {atom, byte} -> {byte, atom} end)
  @negotiation_bytes_to_atoms Map.new(@negotiation, fn {atom, byte} -> {byte, atom} end)
  @capability_bytes_to_atoms Map.new(@capabilities, fn {atom, byte} -> {byte, atom} end)

  def negotiate([:iac, n_atom, c_atom])
      when n_atom in @negotiation_atoms and c_atom in @capability_atoms do
    n_byte = Map.fetch!(@negotiation, n_atom)
    c_byte = Map.fetch!(@capabilities, c_atom)
    <<@iac, n_byte, c_byte>>
  end

  def negotiate([:iac, n_atom, c_byte])
      when n_atom in @negotiation_atoms and is_integer(c_byte) do
    n_byte = Map.fetch!(@negotiation, n_atom)
    <<@iac, n_byte, c_byte>>
  end

  def request_terminal_type do
    # IAC SB TERMINAL_TYPE SEND SE
    <<@iac, @subopt_begin, @terminal_type, 1, @iac, @subopt_end>>
  end

  def offer_utf8_charset do
    # IAC SB CHARSET REQUEST [separator] "UTF-8" SE
    <<@iac, @subopt_begin, @charset, 1, 1, "UTF-8", @iac, @subopt_end>>
  end

  def parse(<<@iac, @iac, rest::binary>>), do: {:data, <<@iac>>, rest}

  def parse(<<@iac, byte, rest::binary>>) when byte in @command_bytes do
    atom = Map.fetch!(@command_bytes_to_atoms, byte)
    {:command, [:iac, atom], rest}
  end

  def parse(<<@iac, n_byte, c_byte, rest::binary>>) when n_byte in @negotiation_bytes do
    n_atom = Map.fetch!(@negotiation_bytes_to_atoms, n_byte)
    c_atom = Map.get(@capability_bytes_to_atoms, c_byte, c_byte)
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
  #  - IAC subopt with no terminator is already handled above

  defp parse_subopt(<<@terminal_type, 0, type::binary>>), do: [:terminal_type, type]
  defp parse_subopt(<<@charset, 2, encoding::binary>>), do: [:charset, {:accepted, encoding}]
  defp parse_subopt(<<@charset, 3, encoding::binary>>), do: [:charset, {:rejected, encoding}]

  defp parse_subopt(<<@naws, width::integer-size(16), height::integer-size(16)>>),
    do: [:naws, {width, height}]

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
