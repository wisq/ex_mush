defmodule Mix.Tasks.ExMush.Db.Import do
  @moduledoc "Imports a PennMUSH DB flatfile into ExMUSH"
  @shortdoc @moduledoc

  use Mix.Task
  alias ExMUSH.DB.Repo
  alias ExMUSH.DB.Object
  alias ExMUSH.DB.Object.Attribute

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
    obj_count = Repo.aggregate(Object, :count, :id)
    attr_count = Repo.aggregate(Attribute, :count, :id)

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

  def load_database(file) do
    File.stream!(file, :line, [:compressed])
    |> Stream.map(&:string.chomp/1)
    |> Stream.transform(nil, &parse_db/2)
    |> Enum.each(&load_db/1)
  end

  defmodule Parsers do
    def parse_string(~s{"} <> str) do
      {before, ~s{"}} = String.split_at(str, -1)

      before
      |> String.replace(~r{\\.}, fn
        ~s{\\"} -> ~s{"}
      end)
    end

    def parse_obj_id("#-1"), do: nil
    def parse_obj_id("#" <> idstr), do: String.to_integer(idstr)

    def parse_type("1"), do: :room
    def parse_type("2"), do: :thing
    def parse_type("4"), do: :exit
    def parse_type("8"), do: :player

    def parse_timestamp(tstr) do
      tstr
      |> String.to_integer()
      |> DateTime.from_unix!()
      |> then(fn %DateTime{microsecond: {0, 0}} = dt ->
        %DateTime{dt | microsecond: {0, 6}}
      end)
    end

    @obj_flags Ecto.Enum.mappings(Object, :flags)
               |> Map.new(fn {atom, str} -> {String.upcase(str), atom} end)

    @attr_flags Ecto.Enum.mappings(Attribute, :flags)
                |> Map.new(fn {atom, str} -> {String.upcase(str), atom} end)

    def parse_obj_flags(fstr), do: parse_flags(fstr, @obj_flags)
    def parse_attr_flags(fstr), do: parse_flags(fstr, @attr_flags)

    defp parse_flags(fstr, flags) do
      fstr
      |> parse_string()
      |> String.downcase()
      |> String.split()
      |> Enum.map(&Map.get(flags, &1))
      |> Enum.reject(&is_nil/1)
    end
  end

  defmodule Header do
    import Parsers

    defstruct(
      version: nil,
      saved_at: nil
    )

    def parse("dbversion " <> vstr, %Header{} = h) do
      v = String.to_integer(vstr)
      %Header{h | version: v}
    end

    def parse("savedtime " <> t, %Header{} = h) do
      %Header{h | saved_at: parse_string(t)}
    end

    def announce(%Header{version: v, saved_at: sa}) do
      IO.puts("*** Loading database version #{v}, saved at #{sa} ***")
    end
  end

  defmodule AttrData do
    alias __MODULE__, as: AD
    import Parsers

    @enforce_keys [:name]
    defstruct(
      name: nil,
      value: nil,
      owner_id: nil,
      flags: nil
    )

    def new(name), do: %AD{name: parse_string(name)}

    def parse("  value " <> v, %AD{} = attr), do: %AD{attr | value: parse_string(v)}
    def parse("  owner " <> oid, %AD{} = attr), do: %AD{attr | owner_id: parse_obj_id(oid)}
    def parse("  flags " <> f, %AD{} = attr), do: %AD{attr | flags: parse_attr_flags(f)}
    def parse("  derefs " <> _, attr), do: attr

    def row_data(%AD{} = ad, oid, now) do
      Map.from_struct(ad)
      |> Map.put(:object_id, oid)
      |> Map.put(:inserted_at, now)
      |> Map.put(:updated_at, now)
    end
  end

  defmodule AttrList do
    @enforce_keys [:object_id, :count]
    defstruct(
      object_id: nil,
      count: nil,
      attrs: []
    )

    def new(oid, cstr) do
      count = String.to_integer(cstr)
      %AttrList{object_id: oid, count: count}
    end

    def parse(" name " <> name, %AttrList{attrs: rest} = list) do
      %AttrList{list | attrs: [AttrData.new(name) | rest]}
    end

    def parse(line, %AttrList{attrs: [old | rest]} = list) do
      new = AttrData.parse(line, old)
      %AttrList{list | attrs: [new | rest]}
    end

    def attrs_row_data(%AttrList{object_id: oid, count: count, attrs: attrs}, now) do
      ^count = Enum.count(attrs)
      attrs |> Enum.map(&AttrData.row_data(&1, oid, now))
    end
  end

  defmodule ObjectData do
    alias __MODULE__, as: OD
    import Parsers

    @enforce_keys [:id]
    defstruct(
      id: nil,
      inserted_at: nil,
      updated_at: nil,
      name: nil,
      type: nil,
      flags: nil,
      location_id: nil,
      parent_id: nil,
      owner_id: nil,
      link_id: nil,
      _attrs: nil
    )

    def new(idstr) do
      id = String.to_integer(idstr)
      %ObjectData{id: id}
    end

    def parse("name " <> name, %OD{} = obj), do: %OD{obj | name: parse_string(name)}
    def parse("type " <> t, %OD{} = obj), do: %OD{obj | type: parse_type(t)}

    def parse("created " <> t, %OD{} = obj), do: %OD{obj | inserted_at: parse_timestamp(t)}
    def parse("modified " <> t, %OD{} = obj), do: %OD{obj | updated_at: parse_timestamp(t)}

    def parse("location " <> oid, %OD{} = obj), do: %OD{obj | location_id: parse_obj_id(oid)}
    def parse("parent " <> oid, %OD{} = obj), do: %OD{obj | parent_id: parse_obj_id(oid)}
    def parse("owner " <> oid, %OD{} = obj), do: %OD{obj | owner_id: parse_obj_id(oid)}
    def parse("exits " <> oid, %OD{} = obj), do: %OD{obj | link_id: parse_obj_id(oid)}

    def parse("flags " <> f, %OD{} = obj), do: %OD{obj | flags: parse_obj_flags(f)}

    def parse("attrcount " <> count, %OD{id: oid, _attrs: nil} = obj),
      do: %OD{obj | _attrs: AttrList.new(oid, count)}

    def parse(" " <> _ = line, %OD{_attrs: %AttrList{} = attrs} = obj),
      do: %OD{obj | _attrs: AttrList.parse(line, attrs)}

    # Data we don't care about:
    def parse("contents " <> _, obj), do: obj
    def parse("next " <> _, obj), do: obj
    def parse("lockcount " <> _, obj), do: obj
    def parse("zone " <> _, obj), do: obj
    def parse("pennies " <> _, obj), do: obj
    def parse("powers " <> _, obj), do: obj
    def parse("warnings " <> _, obj), do: obj

    # FIXME sub-stuff
    def parse(" " <> _, obj), do: obj

    def row_data(%OD{} = od) do
      Map.from_struct(od)
      |> Map.delete(:_attrs)
    end
  end

  defmodule ObjectList do
    @enforce_keys [:next_id]
    defstruct(
      next_id: nil,
      objects: []
    )

    def new(idstr) do
      id = String.to_integer(idstr)
      %ObjectList{next_id: id}
    end

    def parse("!" <> idstr, %ObjectList{objects: objs} = list) do
      obj = ObjectData.new(idstr)
      %ObjectList{list | objects: [obj | objs]}
    end

    def parse(line, %ObjectList{objects: [old | rest]} = list) do
      new = ObjectData.parse(line, old)
      %ObjectList{list | objects: [new | rest]}
    end

    def load(%ObjectList{objects: objs}) do
      Repo.transact(fn ->
        Repo.delete_all(Attribute)
        Repo.delete_all(Object)

        objs
        |> Enum.map(&ObjectData.row_data/1)
        |> then(&Repo.insert_all(Object, &1))

        now = DateTime.utc_now()

        objs
        |> Enum.flat_map(&AttrList.attrs_row_data(&1._attrs, now))
        |> then(&Repo.insert_all(Attribute, &1))

        {:ok, :ok}
      end)
    end
  end

  def parse_db("+V" <> _, nil), do: {[], %Header{}}
  def parse_db("+FLAGS LIST", last), do: {[last], :flags_list}
  def parse_db("+POWER LIST", last), do: {[last], :power_list}
  def parse_db("+ATTRIBUTES LIST", last), do: {[last], :attributes_list}
  def parse_db("~" <> next_id, last), do: {[last], ObjectList.new(next_id)}
  def parse_db("***END OF DUMP***", last), do: {[last], :end}

  def parse_db(line, %Header{} = h), do: {[], Header.parse(line, h)}
  def parse_db(line, %ObjectList{} = o), do: {[], ObjectList.parse(line, o)}
  def parse_db(_, s) when s in [:flags_list, :power_list, :attributes_list], do: {[], s}

  def load_db(%Header{} = h), do: Header.announce(h)
  def load_db(junk) when junk in [:flags_list, :power_list, :attributes_list], do: :noop
  def load_db(%ObjectList{} = list), do: ObjectList.load(list)
end
