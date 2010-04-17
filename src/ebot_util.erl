%%%-------------------------------------------------------------------
%%% File    : ebot_util.erl
%%% Author  : matteo <matteo@nowar>
%%% Description : 
%%%
%%% Created :  4 Oct 2009 by matteo <matteo@nowar>
%%%-------------------------------------------------------------------
-module(ebot_util).

%% API
-export([ 
	  load_settings/1,
	  info/1,
	  remove_duplicates/1,
	  safe_binary_to_list/1,
	  safe_list_to_binary/1
	 ]).

%%====================================================================
%% EBOT specific Internal functions
%%====================================================================

info(Config) ->
    Keys = proplists:get_keys(Config),
    KeysStrings =
	lists:map(
	  fun(X) -> atom_to_list(X) end,
	  Keys),
    Reply = "Options keys: " ++ string:join( KeysStrings, ", "),
    Reply.

load_settings(Module) ->
    %% TODO checking if file exists
    %% TODO compile all regexps inside the file
    File = filename:join([
			  filename:dirname(code:which(?MODULE)),
			  "..", "priv", atom_to_list(Module) ++ ".conf"]),
    io:format("REading config file ~s", [File]),
    file:consult(File).

remove_duplicates(L) ->
    lists:usort(L).

safe_binary_to_list(B) when is_binary(B) ->
    binary_to_list(B);
safe_binary_to_list(B) -> B.

safe_list_to_binary(L) when is_list(L) ->
    list_to_binary(L);
safe_list_to_binary(L) -> L.
    
    
