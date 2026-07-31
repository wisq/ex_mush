defmodule ExMUSH.ObjectIDTest do
  use ExUnit.Case, async: true
  require ExMUSH
  alias ExMUSH.ObjectID

  describe "without ctime" do
    test "to_string" do
      assert %ObjectID{id: 123} |> to_string() == "#123"
      assert %ObjectID{id: 456} |> to_string() == "#456"
      assert %ObjectID{id: -1} |> to_string() == "#-1"
    end

    test "inspect" do
      assert %ObjectID{id: 123} |> inspect() == "~o'#123'"
      assert %ObjectID{id: 456} |> inspect() == "~o'#456'"
      assert %ObjectID{id: -1} |> inspect() == "~o'#-1'"
    end
  end

  describe "with ctime" do
    test "to_string" do
      assert %ObjectID{id: 123, ctime: 456} |> to_string() == "#123:456"
      assert %ObjectID{id: 456, ctime: 789} |> to_string() == "#456:789"
      assert %ObjectID{id: -1, ctime: 123} |> to_string() == "#-1"
    end

    test "inspect" do
      assert %ObjectID{id: 123, ctime: 456} |> inspect() == "~o'#123:456'"
      assert %ObjectID{id: 456, ctime: 789} |> inspect() == "~o'#456:789'"
      assert %ObjectID{id: -1, ctime: 123} |> inspect() == "~o'#-1'"
    end
  end

  test "parse" do
    assert {:ok, %ObjectID{id: 123, ctime: nil}} = ObjectID.parse("#123")
    assert {:ok, %ObjectID{id: 456, ctime: 789}} = ObjectID.parse("#456:789")
    assert {:ok, %ObjectID{id: -1, ctime: nil}} = ObjectID.parse("#-1")

    assert :error = ObjectID.parse("#abc")
    assert :error = ObjectID.parse("#123abc")
    assert :error = ObjectID.parse("abc")
    assert :error = ObjectID.parse("123")
    assert :error = ObjectID.parse("123:456")
    assert :error = ObjectID.parse("#-1:123")
  end

  defp compile(code) do
    {term, _binding} = Code.eval_string("import ExMUSH; #{code}")
    term
  end

  test "sigil_o" do
    assert %ObjectID{id: 123, ctime: nil} = compile("~o'#123'")
    assert %ObjectID{id: 456, ctime: 789} = compile("~o'#456:789'")
    assert %ObjectID{id: -1, ctime: nil} = compile("~o'#-1'")
    assert_raise MatchError, fn -> compile("~o'#abc'") end
    assert_raise MatchError, fn -> compile("~o'#123abc'") end
    assert_raise MatchError, fn -> compile("~o'abc'") end
    assert_raise MatchError, fn -> compile("~o'123'") end
    assert_raise MatchError, fn -> compile("~o'123:456'") end
    assert_raise MatchError, fn -> compile("~o'#-1:123'") end
  end

  test "is_object_id" do
    assert ExMUSH.is_object_id(%ObjectID{id: 123, ctime: nil}) == true
    assert ExMUSH.is_object_id(%ObjectID{id: 456, ctime: 789}) == true
    assert ExMUSH.is_object_id(%ObjectID{id: -1, ctime: nil}) == true
    assert ExMUSH.is_object_id(nil) == false
    assert ExMUSH.is_object_id("#123") == false
    assert ExMUSH.is_object_id(123) == false
  end
end
