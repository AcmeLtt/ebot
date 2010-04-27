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
	 is_valid_url_using_known_invalid_regexps/1,
	 is_valid_url_using_mime_regexps/2,
	 is_valid_url_using_url_regexps/2,
	 normalize_url/2,
	 parse_url/1,
	 url_context/1,
	 url_depth/1,
	 url_domain/1
	]).

%%--------------------------------------------------------------------
%% Function: convert_to_absolute_url
%% Input: an url and its referral/parent url
%% Description: converts relative urls to absolute
%%--------------------------------------------------------------------
	      
convert_to_absolute_url( Url, ParentUrl) ->
    case re:run(Url, "^http") of
	{match, _L} ->
	    Url;
	nomatch ->
	    {Domain,Folder,_File,_Query} = parse_url(ParentUrl),
	    case re:run(Url, "^/") of
		{match, _L} ->
		    Domain ++ Url;
		nomatch ->
		    Domain ++ normalize_path(Folder ++ Url)
	    end
    end.

is_valid_url_using_known_invalid_regexps(Url) ->
    RElist = [
	      {nomatch, "feed:"},
	      {nomatch, "javascript:"},
	      {nomatch, "mailto:"}
	     ],
    ebot_util:is_valid_using_regexps(Url, RElist).

is_valid_url_using_mime_regexps(Url, RElist) -> 
    Mime = mochiweb_util:guess_mime(Url),
    ebot_util:is_valid_using_regexps(Mime, RElist).

is_valid_url_using_url_regexps(Url, RElist) -> 
    ebot_util:is_valid_using_regexps(Url, RElist).
 
%% options: 
%%   without_internal_links
%%   without_queries
normalize_url(Url, Options) when is_binary(Url) ->
    normalize_url(binary_to_list(Url), Options);
normalize_url(Url, Options) ->
    %% sometimes I have found some spaces at the end ...
    U1 = string:strip(Url,  both, $ ),
    U2 = normalize_url_parsing_options(U1, Options),
    U3 = normalize_url_using_known_regexps_replacements(U2),
    U3.

parse_path(Path) ->
    Sep = string:rstr(Path,"/"),
    {string:sub_string(Path,1, Sep), string:sub_string(Path, Sep + 1)}.

parse_url(Url) when is_binary(Url) ->
    parse_url( binary_to_list(Url));

parse_url(Url) ->
    case http_uri:parse(Url) of
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

url_context(Url) ->
    {Domain,Folder,_File,_Query} = parse_url(Url),
    Domain ++ Folder.

url_depth(Url) ->
    {_Domain,Folder,_File,_Query} = parse_url(Url),
    length(string:tokens(Folder, "/")).

url_domain(Url) ->
    {Domain,_,_,_} = ebot_url_util:parse_url(Url),
    Domain.
   
%%====================================================================
%% EBOT_Url specific Internal functions
%%====================================================================

normalize_path(Path) ->
    Tokens = lists:reverse(string:tokens(Path,"/")),
    case normalize_path( Tokens, {0,[]}) of
	{ok, ""} ->
	    "/";
	{ok, NewTokens} ->
	    "/" ++ string:join(NewTokens,"/");
	{error, _} ->
	    "/"
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

normalize_url_parsing_options(Url, [{max_depth,MaxDepth}|Options]) ->
    NewUrl = url_with_max_depth(Url, MaxDepth),
    normalize_url_parsing_options(NewUrl, Options);

normalize_url_parsing_options(Url, [without_internal_links|Options]) ->
    NewUrl = url_without_internal_links(Url),
    normalize_url_parsing_options(NewUrl, Options);

normalize_url_parsing_options(Url, [without_queries|Options]) ->
    NewUrl = url_without_queries(Url),
    normalize_url_parsing_options(NewUrl, Options);

normalize_url_parsing_options(Url, [Opt|Options]) ->
    io:format("normalize_url_parsing_options: skipping unknown option '~ts'", 
	      [atom_to_list(Opt)]),
    normalize_url_parsing_options(Url, Options);
normalize_url_parsing_options(Url, []) ->
    Url.

normalize_url_using_known_regexps_replacements(Url) ->
    %% examples:
    RElist = [
    %% http://www.gettyre.it/motoweb/cart_input.action;jsessionid=250485CC578DA975CDD6099249EDD203.saetta_1
	      {";[A-Za-z0-9]+=[^&;?]+", ""}
	     ],
    ebot_util:string_replacements_using_regexps(Url, RElist).

url_unparse({Domain,Folder,File,Query}) ->
    Domain ++ Folder ++ File ++ Query.

url_with_max_depth(Url, MaxDepth) ->
    Depth = url_depth(Url),
    url_with_max_depth(Url, MaxDepth, Depth).

url_with_max_depth(Url, MaxDepth, Depth) when Depth =< MaxDepth->
    Url;
url_with_max_depth(Url, MaxDepth, _Depth) ->
    {Domain,Folder,_File,_Query} = parse_url(Url),
    Tokens = string:tokens(Folder, "/"),
    NewTokens = lists:sublist(Tokens, MaxDepth),
    NewFolder = "/" ++ string:join(NewTokens,"/") ++ "/",
    url_unparse({Domain,NewFolder,"",""}).

url_without_internal_links(Url) ->
    {Scheme, Netloc, Path, Query, _Fragment} = mochiweb_util:urlsplit(Url),
    mochiweb_util:urlunsplit({Scheme, Netloc, Path, Query,[]}).

url_without_queries(Url) ->
    {Scheme, Netloc, Path, _Query, _Fragment} = mochiweb_util:urlsplit(Url),
    mochiweb_util:urlunsplit({Scheme, Netloc, Path, [],[]}).
