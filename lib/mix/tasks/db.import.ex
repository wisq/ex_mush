defmodule Mix.Tasks.ExMush.Db.Import do
  @moduledoc "Imports a PennMUSH DB flatfile into ExMUSH"
  @shortdoc @moduledoc

  use Mix.Task
  alias ExMUSH.DB
  alias ExMUSH.DB.Repo
  alias ExMUSH.Import
  alias Ecto.Adapters.SQL

  @schemas [DB.Object, DB.Object.Attribute]
  @chunk_size 100

  @task_name Mix.Task.task_name(__MODULE__)
  @options [
    force: :boolean
  ]

  defp usage, do: "Usage:  mix #{@task_name} [--force] path/to/outdb.gz"

  def run(argv) do
    {opts, args} = OptionParser.parse!(argv, strict: @options)
    force = Keyword.get(opts, :force, false)
    do_run(args, force)
  end

  defp do_run([file], force) do
    {:ok, _} = Application.ensure_all_started([:ex_mush])
    sanity_check(force)
    load_database(file)
  end

  defp do_run([], _), do: Mix.raise("Must specify a database filename.\n\n#{usage()}")
  defp do_run(files, _), do: Mix.raise("Too many filenames: #{inspect(files)}\n\n#{usage()}")

  defp sanity_check(force) do
    obj_count = Repo.aggregate(DB.Object, :count, :id)
    attr_count = Repo.aggregate(DB.Object.Attribute, :count, :id)

    IO.puts("Existing database contains #{obj_count} objects and #{attr_count} attributes.")

    cond do
      obj_count == 0 and attr_count == 0 ->
        IO.puts("No existing data, load can proceed.")

      force == true ->
        IO.puts("Proceeding with load anyway due to --force.")

      true ->
        Mix.raise("""
        Cowardly refusing to DELETE ALL CURRENT DATA.
        If you really want to do this, run this command again with --force.
        """)
    end
  end

  defp load_database(file) do
    try do
      defer_constraints(true)

      Repo.transact(fn ->
        delete_all()

        File.stream!(file, :line, [:compressed])
        |> Stream.map(&:string.chomp/1)
        |> Stream.transform(nil, &section_chunk/2)
        |> Stream.map(&Enum.reverse/1)
        |> Stream.map(&parse_chunk/1)
        |> Stream.drop_while(&handle_header/1)
        |> Stream.chunk_every(@chunk_size)
        |> Enum.each(&load_chunk/1)

        {:ok, nil}
      end)
    after
      defer_constraints(false)
    end
  end

  defp section_chunk(header, nil), do: {[], [header]}
  defp section_chunk("+" <> _ = header, last), do: {[last], [header]}
  defp section_chunk("~" <> _, last), do: {[last], nil}
  defp section_chunk("!" <> _ = header, last), do: {[last], [header]}
  defp section_chunk("***END OF DUMP***", last), do: {[last], :end}
  defp section_chunk(line, rest), do: {[], [line | rest]}

  defp parse_chunk(["+V" <> _ | data]), do: Import.Header.parse(data)
  defp parse_chunk(["!" <> oid | data]), do: Import.Object.parse(oid, data)

  defp parse_chunk(["+FLAGS LIST" | _]), do: :flags_list
  defp parse_chunk(["+POWER LIST" | _]), do: :power_list
  defp parse_chunk(["+ATTRIBUTES LIST" | _]), do: :attrs_list

  defp handle_header(%Import.Header{} = h), do: Import.Header.announce(h) || true
  defp handle_header(%Import.Object{}), do: false

  # Ignored.
  defp handle_header(h) when is_atom(h), do: true

  defp defer_constraints(defer?) do
    @schemas
    |> Enum.map(& &1.__schema__(:source))
    |> Enum.each(&defer_table_constraints(&1, defer?))
  end

  defp defer_table_constraints(table, defer?) do
    get_fkey_constraints(table)
    |> Enum.map(fn fkey ->
      case defer? do
        true -> "ALTER CONSTRAINT #{fkey} DEFERRABLE INITIALLY DEFERRED"
        false -> "ALTER CONSTRAINT #{fkey} NOT DEFERRABLE"
      end
    end)
    |> Enum.join(", ")
    |> then(fn sql ->
      {:ok, _} = SQL.query(Repo, "ALTER TABLE #{table} #{sql}")
    end)
  end

  defp get_fkey_constraints(table) do
    {:ok, %{rows: rows}} =
      SQL.query(
        Repo,
        "SELECT conname FROM pg_constraint " <>
          "WHERE conrelid = $1::text::regclass AND contype = 'f'",
        [table]
      )

    rows |> List.flatten()
  end

  defp delete_all, do: @schemas |> Enum.map(&Repo.delete_all/1)

  defp load_chunk(objs) do
    now = DateTime.utc_now()

    objs
    |> Enum.map(&Import.Object.row_data/1)
    |> then(&Repo.insert_all(DB.Object, &1))

    objs
    |> Enum.flat_map(& &1.attrs)
    |> Enum.map(&Import.Attribute.row_data(&1, now))
    |> then(&Repo.insert_all(DB.Object.Attribute, &1))
  end
end

defmodule ExMUSH.Import.Header do
  @enforce_keys [:version, :saved_at]
  defstruct(@enforce_keys)

  alias __MODULE__
  alias ExMUSH.Import.DataTree

  def parse(lines) do
    IO.puts("parsing header")

    DataTree.parse(lines)
    |> Map.new(fn {key, value} -> parse_data(key, value) end)
    |> then(&struct!(Header, &1))
  end

  defp parse_data(:dbversion, v), do: {:version, v}
  defp parse_data(:savedtime, t), do: {:saved_at, t}

  def announce(%Header{version: v, saved_at: t}) do
    IO.puts("*** Loading database version #{v}, saved at #{t} ***")
  end
end

defmodule ExMUSH.Import.Object do
  @enforce_keys [
    :id,
    :inserted_at,
    :updated_at,
    :name,
    :type,
    :flags,
    :location_id,
    :parent_id,
    :owner_id,
    :link_id,
    :attrs
  ]
  defstruct(@enforce_keys)

  alias __MODULE__
  alias ExMUSH.Import.DataTree
  alias ExMUSH.Import.Parse
  alias ExMUSH.Import.Attribute

  def parse(idstr, lines) do
    id = String.to_integer(idstr)

    DataTree.parse(lines)
    |> Enum.flat_map(fn {key, value} -> parse_data(key, value) end)
    |> Map.new()
    |> Map.put(:id, id)
    |> Map.update!(:attrs, fn attrs ->
      attrs |> Enum.map(&Attribute.parse(id, &1))
    end)
    |> then(&struct!(Object, &1))
  end

  def row_data(%Object{} = obj) do
    Map.from_struct(obj)
    |> Map.delete(:attrs)
  end

  defp parse_data(:exits, oid), do: [link_id: oid]
  defp parse_data(:flags, flags), do: [flags: Parse.object_flags(flags)]
  defp parse_data(:created, t), do: [inserted_at: Parse.unix_time(t)]
  defp parse_data(:modified, t), do: [updated_at: Parse.unix_time(t)]

  defp parse_data(key, value) when key in [:name, :attrs], do: [{key, value}]

  defp parse_data(key, value) when key in [:owner, :parent, :location],
    do: [{:"#{key}_id", value}]

  defp parse_data(key, _)
       when key in [:contents, :next, :locks, :zone, :pennies, :powers, :warnings], do: []

  defp parse_data(:type, 1), do: [type: :room]
  defp parse_data(:type, 2), do: [type: :thing]
  defp parse_data(:type, 4), do: [type: :exit]
  defp parse_data(:type, 8), do: [type: :player]
end

defmodule ExMUSH.Import.Attribute do
  @enforce_keys [:object_id, :name, :value, :owner_id, :flags]
  defstruct(@enforce_keys)

  alias __MODULE__
  alias ExMUSH.Import.Parse

  def parse(obj_id, data) do
    data
    |> Enum.flat_map(fn {key, value} -> parse_data(key, value) end)
    |> Map.new()
    |> Map.put(:object_id, obj_id)
    |> then(&struct!(Attribute, &1))
  end

  def row_data(%Attribute{} = attr, now) do
    Map.from_struct(attr)
    |> Map.put(:inserted_at, now)
    |> Map.put(:updated_at, now)
  end

  defp parse_data(:flags, flags), do: [flags: Parse.attribute_flags(flags)]
  defp parse_data(key, value) when key in [:name, :value], do: [{key, value}]
  defp parse_data(key, value) when key in [:owner], do: [{:"#{key}_id", value}]
  defp parse_data(key, _) when key in [:derefs], do: []
end

defmodule ExMUSH.Import.DataTree do
  def parse(lines) do
    lines
    |> Enum.map(&parse_line/1)
    |> build_nested_tree()
  end

  defp parse_line(line) do
    {depth, line} = measure_depth(line)
    [key, value] = String.split(line, " ", parts: 2)
    {depth, key, parse_value(value)}
  end

  defp build_nested_tree([]), do: []

  defp build_nested_tree([{depth, key, value} | rest]) do
    {under_me, after_me} = rest |> Enum.split_while(fn {d, _, _} -> d > depth end)
    [tree_item(key, value, under_me) | build_nested_tree(after_me)]
  end

  defp tree_item(key, value, contents) do
    contents = build_nested_tree(contents)

    cond do
      String.ends_with?(key, "count") ->
        # It's a list of something.  Change the key to make more sense, and
        # ensure it has the correct number of sub-items (which might be zero).
        key = String.replace_suffix(key, "count", "s") |> String.to_atom()
        ^value = Enum.count(contents)
        {key, contents}

      !Enum.empty?(contents) ->
        # It's just the header for an item in the list.  Merge it into the contents.
        [{String.to_atom(key), value} | contents]

      true ->
        # Just a plain list item.
        {String.to_atom(key), value}
    end
  end

  defp measure_depth(" " <> line) do
    {depth, rest} = measure_depth(line)
    {depth + 1, rest}
  end

  defp measure_depth(line), do: {0, line}

  # String:
  defp parse_value(~s{"} <> str) do
    {before, ~s{"}} = String.split_at(str, -1)

    before
    |> String.replace(~r{\\.}, fn
      ~s{\\"} -> ~s{"}
    end)
  end

  # Object ID:
  defp parse_value("#-1"), do: nil
  defp parse_value("#" <> idstr), do: String.to_integer(idstr)

  # Integer (default):
  defp parse_value(istr), do: String.to_integer(istr)
end

defmodule ExMUSH.Import.Parse do
  def unix_time(tstr) do
    tstr
    |> DateTime.from_unix!()
    |> then(fn %DateTime{microsecond: {0, 0}} = dt ->
      %DateTime{dt | microsecond: {0, 6}}
    end)
  end

  @obj_flags Ecto.Enum.mappings(ExMUSH.DB.Object, :flags)
             |> Map.new(fn {atom, str} -> {String.upcase(str), atom} end)

  @attr_flags Ecto.Enum.mappings(ExMUSH.DB.Object.Attribute, :flags)
              |> Map.new(fn {atom, str} -> {String.upcase(str), atom} end)

  def object_flags(fstr), do: parse_flags(fstr, @obj_flags)
  def attribute_flags(fstr), do: parse_flags(fstr, @attr_flags)

  defp parse_flags(fstr, flags) do
    fstr
    |> String.downcase()
    |> String.split()
    |> Enum.map(&Map.get(flags, &1))
    |> Enum.reject(&is_nil/1)
  end
end
