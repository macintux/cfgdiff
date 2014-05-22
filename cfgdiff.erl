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

%% Option 1: the property lists match exactly, nothing to do. Also
%% matches empty lists.
treediff({Name1, P1}, {Name2, P2}, Label, Accum) when P1 =:= P2 ->
    lists:reverse(Accum);
%% Option: ran out of items in only one list
treediff({Name1, P1}, {Name2, []}, Label, Accum) ->
    [{Label, {Name1, P1}}] ++ Accum;
%% Option: ran out of items in only one list
treediff([], {Name2, P2}, Label, Accum) ->
    [{Label, {Name2, P2}}] ++ Accum;
%% Option 2: the head of each list matches, check the tails
treediff({Name1, [H1|T1]=P1}, {Name2, [H1|T2]=P2}, Label, Accum) ->
    treediff({Name1, T1}, {Name2, T2}, Label, Accum);
%% Option 3: the key at the head of each list matches, check
%% the nested values before checking the tails
treediff({Name1, [{K1, V1}|T1]=P1}, {Name2, [{K1, V2}|T2]=P2}, Label, Accum) ->
    treediff({Name1, T1}, {Name2, T2}, Label,
             treediff({Name1, V1}, {Name2, V2},
                      Label ++ "/" ++ atom_to_list(K1), Accum));
%% Option 4: the key at the head of list 1 does not exist in list
%% 2. Capture the head of list 1 and try again with the next element,
%% but retain the entirety of list 2
treediff({Name1, [{K1, V1}|T1]=P1}, {Name2, [{K2, V2}|T2]=P2}, Label, Accum)
  when K1 < K2 ->
    treediff({Name1, T1}, {Name2, P2}, Label,
             [{Label, {Name1, {K1, V1}}}] ++ Accum);
%% Option 5: the key at the head of list 2 does not exist in list
%% 1. Capture the head of list 2 and try again with the next element,
%% but retain the entirety of list 1.
%%
%% Guard is redundant but makes things more explicit.
treediff({Name1, [{K1, V1}|T1]=P1}, {Name2, [{K2, V2}|T2]=P2}, Label, Accum)
  when K1 > K2 ->
    treediff({Name1, P1}, {Name2, T2}, Label,
             [{Label, {Name2, {K2, V2}}}] ++ Accum);
treediff({Name1, P1}, {Name2, P2}, Label, Accum) ->
    %% If we reach this point, one or the other isn't actually a list,
    %% so let's just capture the different values and move on
    [{Label, {Name1, P1}, {Name2, P2}}] ++ Accum.


deepsort(P1) ->
    sort_elements(lists:sort(P1), []).

sort_elements([], Accum) ->
    lists:reverse(Accum);
sort_elements([H|T], Accum) when not is_list(H) ->
    sort_elements(T, [H] ++ Accum);
sort_elements([List|T], Accum) ->
    sort_elements(T, sort_elements(lists:sort(List), []) ++ Accum).
