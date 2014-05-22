%%% @author John Daily <jd@epep.us>
%%% @copyright (C) 2014, John Daily
%%% @doc
%%%
%%% @end
%%% Created : 21 May 2014 by John Daily <jd@epep.us>

-module(cfgdiff).
-compile(export_all).

unique_names(Path1, Path2) ->
    Tokenized1 = string:tokens(Path1, "/"),
    Tokenized2 = string:tokens(Path2, "/"),
    pick_unique(Tokenized1, Tokenized2).

pick_unique([], []) ->
    %% Hard to imagine how this would happen, but whatev
    {"file1", "file2"};
pick_unique([H1|T1], [H1|T2]) ->
    pick_unique(T1, T2);
pick_unique([H1|T1], [H2|T2]) ->
    {H1, H2}.


filediff(Path1, Path2) ->
    {ok, P1} = file:consult(Path1),
    {ok, P2} = file:consult(Path2),
    {Name1, Name2} = unique_names(Path1, Path2),
    diff({Name1, P1}, {Name2, P2}).
    

diff({Name1, List1}, {Name2, List2}) ->
    treediff({Name1, deepsort(List1)}, {Name2, deepsort(List2)}, "", []).

%% treediff will only work as designed if the lists are sorted all the
%% way down

%% The property lists match exactly, nothing to do. Also matches empty
%% lists to terminate the recursion.
treediff({Name1, P1}, {Name2, P2}, Label, Accum) when P1 =:= P2 ->
    lists:reverse(Accum);

%% Ran out of items in the second list
treediff({Name1, P1}, {Name2, []}, Label, Accum) ->
    [{Label, {Name1, P1}}] ++ Accum;

%% Ran out of items in the first list
treediff({Name1, []}, {Name2, P2}, Label, Accum) ->
    [{Label, {Name2, P2}}] ++ Accum;

%% The head of each list matches exactly, check the tails. Match the
%% full tuple at the head of each list so that we don't accidentally
%% start matching integers in strings, and check for atoms in the key
%% so we don't sort non-proplist elements like {"IP", port}
treediff({Name1, [{K1, _V1}|T1]=P1}, {Name2, [{K1, _V1}|T2]=P2}, Label, Accum) when is_atom(K1) ->
    treediff({Name1, T1}, {Name2, T2}, Label, Accum);

%% The key at the head of each list matches, check the nested values
%% before checking the tails
treediff({Name1, [{K1, V1}|T1]=P1}, {Name2, [{K1, V2}|T2]=P2}, Label, Accum) when is_atom(K1) ->
    treediff({Name1, T1}, {Name2, T2}, Label,
             treediff({Name1, V1}, {Name2, V2},
                      Label ++ "/" ++ atom_to_list(K1), Accum));

%% The key at the head of list 1 does not exist in list 2. Capture the
%% head of list 1 and try again with the next element; continue with the
%% entirety of list 2
treediff({Name1, [{K1, V1}|T1]=P1}, {Name2, [{K2, V2}|T2]=P2}, Label, Accum)
  when is_atom(K1) andalso K1 < K2 ->
    treediff({Name1, T1}, {Name2, P2}, Label,
             [{Label, {Name1, {K1, V1}}}] ++ Accum);

%% The key at the head of list 2 does not exist in list 1. Capture the
%% head of list 2 and try again with the next element; continue with
%% the entirety of list 1
treediff({Name1, [{K1, V1}|T1]=P1}, {Name2, [{K2, V2}|T2]=P2}, Label, Accum)
  when is_atom(K1) andalso K1 > K2 ->
    treediff({Name1, P1}, {Name2, T2}, Label,
             [{Label, {Name2, {K2, V2}}}] ++ Accum);

%% If we reach this point, one or the other isn't actually a proplist
%% and they don't match, so let's just capture the different values
%% and move on
treediff({Name1, P1}, {Name2, P2}, Label, Accum) ->
    [{Label, {Name1, P1}, {Name2, P2}}] ++ Accum.


deepsort(P1) ->
    sort_elements(lists:sort(P1), []).

sort_elements([], Accum) ->
    lists:reverse(Accum);
sort_elements([H|T], Accum) when not is_list(H) ->
    sort_elements(T, [tuple_sort(H)] ++ Accum);
sort_elements([List|T], Accum) ->
    sort_elements(T, sort_elements(lists:sort(List), []) ++ Accum).

tuple_sort({K, [{K1, _V1}|_T]=V}) when is_atom(K1) ->
    {K, sort_elements(lists:sort(V), [])};
tuple_sort({K, V}) ->
    {K, V};
%% If we pass something that isn't a tuple, bail
tuple_sort(K) ->
    K.
