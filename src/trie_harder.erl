-module(trie_harder).
-export([build/1, insert/2, find/2, prefix_search/3]).

-record(node, {children = #{} :: #{integer() => #node{}}, exists = false :: boolean(), value = nil :: term()}).


-spec build(list({binary(), term()})) -> #node{}.
build(List) -> build_internal(List, #node{}).


build_internal([], Trie) -> Trie;
build_internal([Head | Tail], Trie) ->
    build_internal(Tail, insert(Trie, Head)).


-spec insert(#node{}, {binary(), term()}) -> #node{}.
insert(Node, {<<>>, Value}) -> Node#node{exists = true, value = Value};
insert(#node{children = Children} = Node, {<<First, Rest/binary>>, Value}) ->
    case Children of
        #{First := Child} -> Node#node{children = Children#{First := insert(Child, {Rest, Value})}};
        _ -> Node#node{children = Children#{First => insert(#node{}, {Rest, Value})}}
    end.


-spec find(#node{}, binary()) -> {ok, term()} | error.
find(Node, <<>>) ->
    case Node#node.exists of
        true -> {ok, Node#node.value};
        false -> error
    end;
find(#node{children = Children}, <<First, Rest/binary>>) ->
    case Children of
        #{First := Child} -> find(Child, Rest);
        _ -> error
    end.


-spec prefix_search(#node{}, binary(), pos_integer()) -> list({binary(), term()}).
prefix_search(Trie, Prefix, Limit) ->
    case find_internal(Trie, Prefix) of
        undefined -> [];
        Node ->
            PrefixList = lists:reverse(binary_to_list(Prefix)),
            {_, Acc} = collect_values(Node, PrefixList, Limit, 0, []),
            lists:reverse(Acc)
    end.


-spec collect_values(#node{}, list(), pos_integer(), non_neg_integer(), list(binary())) -> {non_neg_integer(), list({binary(), term()})}.
collect_values(Node, PrefixList, Limit, Count, Acc) ->
    {NextCount, NextAcc} = case Node#node.exists of
                               true -> {Count + 1, [{iolist_to_binary(lists:reverse(PrefixList)), Node#node.value} | Acc]};
                               false -> {Count, Acc}
                           end,
    if
        NextCount >= Limit -> {NextCount, NextAcc};
        true ->
            Iterator = maps:iterator(Node#node.children),
            fold_children(maps:next(Iterator), PrefixList, Limit, NextCount, NextAcc)
    end.


-spec fold_children(none | {integer(), #node{}, term()}, list(), pos_integer(), non_neg_integer(), list(binary())) -> {non_neg_integer(), list(binary())}.
fold_children(none, _, _, Count, Acc) -> {Count, Acc};
fold_children(_, _, Limit, Count, Acc) when Count >= Limit -> {Count, Acc};
fold_children({Key, Child, NextIterator}, PrefixList, Limit, Count, Acc) ->
    {Count0, Acc0} = collect_values(Child, [Key | PrefixList], Limit, Count, Acc),
    if
        Count0 >= Limit -> {Count0, Acc0};
        true -> fold_children(maps:next(NextIterator), PrefixList, Limit, Count0, Acc0)
    end.


-spec find_internal(#node{} | undefined, binary()) -> #node{} | undefined.
find_internal(undefined, _) -> undefined;
find_internal(Node, <<>>) -> Node;
find_internal(#node{children = Children}, <<First, Rest/binary>>) ->
    case Children of
        #{First := Child} -> find_internal(Child, Rest);
        _ -> undefined
    end.
