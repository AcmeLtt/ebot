%%%-------------------------------------------------------------------
%%% File    : ebot_url_util.erl
%%% Author  : matteo <<matteo.redaelli@@libero.it>
%%% Description : 
%%%
%%% Created :  4 Oct 2009 by matteo <matteo@redaelli.org>
%%%-------------------------------------------------------------------
-module(ebot_url_util).
-author("matteo.redaelli@@libero.it").

%% API
-export([
	 convert_to_absolute_url/2,
	 is_valid_url_regexps/2,
	 parse_url/1,
	 url_context/1
	]).

%%--------------------------------------------------------------------
%% Function: convert_to_absolute_url
%% Input: an url and its referral/parent url
%% Description: converts relative urls to absolute
%%--------------------------------------------------------------------
	      
convert_to_absolute_url( Url, ParentUrl) ->
    %% sometimes I have found some spaces at the end ...
    NewUrl = string:strip(Url,  both, $ ),
    case re:run(NewUrl, "^http") of
	{match, _L} ->
	    NewUrl;
	nomatch ->
	    {Domain,Folder,_File,_Query} = parse_url(ParentUrl),
	    case re:run(NewUrl, "^/") of
		{match, _L} ->
		    Domain ++ NewUrl;
		nomatch ->
		    Domain ++ normalize_path(Folder ++ NewUrl)
	    end
    end.

is_valid_url_regexps(URL, RElist) ->
    lists:all(
      fun({TypeMatching, Reg}) ->
	      TypeMatching == re:run(URL, Reg,[{capture, none},caseless])
      end,
      RElist).

%%====================================================================
%% EBOT_URL specific Internal functions
%%====================================================================

normalize_path(Path) ->
    Tokens = lists:reverse(string:tokens(Path,"/")),
    case normalize_path( Tokens, {0,[]}) of
	{ok, ""} ->
	    "/";
	{ok, NewTokens} ->
	    "/" ++ string:join(NewTokens,"/");
	{error, _} ->
	    "/too_many_backs/"
    end.

normalize_path([".."|L], {Cont,NewList}) ->
    normalize_path(L, {Cont + 1,NewList});

normalize_path([_|L], {Cont,NewList}) when Cont > 0 ->
    normalize_path(L, {Cont - 1,NewList});

% skipping unuseful ./
normalize_path(["."|L], {Cont,NewList}) when Cont == 0 ->
    normalize_path(L, {Cont,NewList});
	
normalize_path([E|L], {Cont,NewList}) when Cont == 0 ->
    normalize_path(L, {Cont,[E|NewList]});

normalize_path([], {0,NewList}) ->
    {ok,NewList};	    
normalize_path([], {_,_}) ->
    {error, too_many_backs}.

    
parse_path(Path) ->
    Sep = string:rstr(Path,"/"),
    {string:sub_string(Path,1, Sep), string:sub_string(Path, Sep + 1)}.

parse_url(URL) ->
    case http_uri:parse(URL) of
	{error, Result} ->
	    {error, Result};
	{Protocol,_,Root,Port,Path,Query} -> 
	    %% TODO: should check protocol/port and not only port
	    case Port of
		80 ->
		    P = "";
		443 ->
		    P = "";
		_Else ->
		    P = ":" ++ integer_to_list(Port)
	    end,
	    Domain = atom_to_list(Protocol) ++ "://" ++ Root ++ P,
	    {Folder, File} = parse_path(Path),
	    {Domain,Folder,File,Query}
    end.

url_context(URL) ->
    {Domain,Folder,_File,_Query} = parse_url(URL),
    Domain ++ Folder.
