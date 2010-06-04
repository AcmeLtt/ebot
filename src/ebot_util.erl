%%%-------------------------------------------------------------------
%%% File    : ebot_util.erl
%%% Author  : matteo <matteo@nowar>
%%% Description : 
%%%
%%% Created :  4 Oct 2009 by matteo <matteo@nowar>
%%%-------------------------------------------------------------------
-module(ebot_util).

-include("ebot.hrl").

%% API
-export([ 
	  get_env/1,
	  load_settings/1,
	  info/1,
	  is_valid_using_all_regexps/2,
	  is_valid_using_any_regexps/2,
	  remove_duplicates/1,
	  safe_binary_to_list/1,
	  safe_list_to_binary/1,
	  string_replacements_using_regexps/2
	 ]).

%%====================================================================
%% EBOT specific Internal functions
%%====================================================================

get_env(Key) ->
    application:get_env(ebot, Key).
    
info(Config) ->
    Keys = proplists:get_keys(Config),
    KeysStrings =
	lists:map(
	  fun(X) -> atom_to_list(X) end,
	  Keys),
    Reply = "Options keys: " ++ string:join( KeysStrings, ", "),
    Reply.


is_valid_using_all_regexps(String, RElist) ->
    lists:all(
      fun({Result, RE}) ->
	      Result == re:run(String, RE, [{capture, none},caseless]) 
      end,
      RElist
     ).

is_valid_using_any_regexps(String, RElist) ->
    lists:any(
      fun({Result, RE}) ->
	      Result == re:run(String, RE, [{capture, none},caseless]) 
      end,
      RElist
     ).

load_settings(Module) ->
    %% TODO checking if file exists
    %% TODO compile all regexps inside the file
    File = filename:join([
			  filename:dirname(code:which(?MODULE)),
			  "..", "priv", atom_to_list(Module) ++ ".conf"]),
    error_logger:warning_report({?MODULE, ?LINE, {opening_configuration_file, File}}),
    file:consult(File).

remove_duplicates(L) ->
    lists:usort(L).

safe_binary_to_list(B) when is_binary(B) ->
    binary_to_list(B);
safe_binary_to_list(B) -> B.

safe_list_to_binary(L) when is_list(L) ->
    list_to_binary(L);
safe_list_to_binary(L) -> L.
    
string_replacements_using_regexps(String, RElist) ->
    lists:foldl(
      fun({From,To}, OldStr) ->
	      re:replace(OldStr, From, To,  [{return,list},global]) end,
      String,
      RElist
     ).

