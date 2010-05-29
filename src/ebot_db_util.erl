%%%-------------------------------------------------------------------
%%% File    : ebot_db_util.erl
%%% Author  : matteo <matteo@pirelli.com>
%%% Description : 
%%%
%%% Created :  4 Apr 2010 by matteo <matteo@pirelli.com>
%%%-------------------------------------------------------------------
-module(ebot_db_util).

-include("ebot.hrl").

%% API
-export([
	 create_url/2,
	 is_html_doc/1,
	 open_url/2,
	 open_or_create_url/2,
	 update_url/3,
	 url_status/3
	]).

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function: 
%% Description:
%%--------------------------------------------------------------------
    
create_url(Db, Url) ->
    Domain = ebot_url_util:url_domain(Url),
    Doc = [
	    {<<"http_returncode">>,0},
	    {<<"content_type">>, <<"">>},
	    {<<"ebot_body_visited">>, 0},
	    {<<"ebot_head_visited">>, 0},
	    {<<"ebot_domain">>, list_to_binary(Domain)},
	    {<<"ebot_errors_count">>, 0},
	    {<<"ebot_links_count">>, 0},
	    {<<"ebot_referrals">>, <<"">>},
	    {<<"ebot_referrals_count">>, 0},
	    {<<"ebot_visits_count">>, 0}
	   ],
    ?EBOT_DB_BACKEND:save_url_doc(Db, Url, dict:from_list(Doc)).

is_html_doc(Doc) ->
    Contenttype = doc_get_value(<<"content_type">>, Doc),
    case re:run(Contenttype, "^text/html",[{capture, none},caseless] ) of
	match ->
	    true;
	nomatch ->
	    false
    end.

open_url(Db, Id) when is_list(Id) ->
    open_url(Db, list_to_binary(Id));
open_url(Db, Id) ->
    ?EBOT_DB_BACKEND:open_url(Db, Id).

open_or_create_url(Db, Url) ->
    case Doc = open_url(Db, Url) of
	not_found ->
	    create_url(Db, Url);
	Doc ->
	    Doc
    end.

update_url(Db, Url, Options) ->
    error_logger:info_report({?MODULE, ?LINE, {update_url, Url, with_options, Options}}),
    Doc = open_url(Db, Url),
    NewDoc = update_url_doc(Doc, Options),
%    error_logger:info_report({?MODULE, ?LINE, {update_url, Url, saving_doc, dict:to_list(NewDoc)}}),
    ?EBOT_DB_BACKEND:save_url_doc(Db, Url, NewDoc).

update_url_doc(Doc, [{link_counts, LinksCount}|Options]) ->
    NewDoc = update_doc_by_key_value(Doc, <<"ebot_links_count">>, LinksCount),
    update_url_doc(NewDoc, Options);
update_url_doc(Doc, [{referral, RefUrl}|Options]) ->
    %% TODO 
    %% managing more than one referral: we need also a job that
    %% periodically checks referrals...
    ReferralsCount = doc_get_value(<<"ebot_referrals_count">>, Doc),
    OldReferralsString = doc_get_value(<<"ebot_referrals">>, Doc),
  
    OldReferrals = re:split(OldReferralsString, " "),
    case lists:member( RefUrl, OldReferrals) of
	true ->
    	    NewReferrals = OldReferrals;
	false ->
	    NewReferrals = [RefUrl|OldReferrals]
    end,
    NewReferralsList = lists:map(fun binary_to_list/1, NewReferrals),
    NewReferralsString = string:join(NewReferralsList, " "),
    NewDoc = update_doc_by_key_value(Doc, <<"ebot_referrals">>, list_to_binary(NewReferralsString)),
    NewDoc2 = update_doc_by_key_value(NewDoc, <<"ebot_referrals_count">>, ReferralsCount + 1),
    update_url_doc(NewDoc2, Options);
update_url_doc(Doc, [body_timestamp|Options]) ->
    NewDoc = update_doc_timestamp_by_key(Doc, <<"ebot_body_visited">>),
    update_url_doc(NewDoc, Options);
update_url_doc(Doc, [head_timestamp|Options]) ->
    NewDoc = update_doc_timestamp_by_key(Doc, <<"ebot_head_visited">>),
    update_url_doc(NewDoc, Options);
update_url_doc(Doc, [{head, Result}|Options]) ->
    NewDoc = update_url_head_doc(Doc, Result),
    update_url_doc(NewDoc, Options);
update_url_doc(Doc, [errors_count|Options]) ->
    NewDoc = update_doc_increase_counter(Doc, <<"ebot_errors_count">>),
    update_url_doc(NewDoc, Options);
update_url_doc(Doc, [reset_errors_count|Options]) ->
    NewDoc = update_doc_by_key_value(Doc, <<"ebot_errors_count">>, 0),
    update_url_doc(NewDoc, Options);
update_url_doc(Doc, [visits_count|Options]) ->
    NewDoc = update_doc_increase_counter(Doc, <<"ebot_visits_count">>),
    update_url_doc(NewDoc, Options);
update_url_doc(Doc, []) ->
    Doc.

update_url_head_doc(Doc, {error, _}) ->
    Doc;
update_url_head_doc(Doc, {ok, {{_,Http_returncode,_}, Headers, _Body}} ) ->
    Header_keys = ebot_header_keys(),	    
    Doc2 = lists:foldl(
	     fun(BKey, Document) ->
		     Value = proplists:get_value(
			       binary_to_list(BKey),
			       Headers,
			       ""),
		     error_logger:info_report({?MODULE, ?LINE, {update_url_head_doc, BKey, Value}}),
		     %% some urls may not contain the header entries we want to trak
		     case Value of
			 undefined ->
			     error_logger:info_report({?MODULE, ?LINE, {update_url_head_doc, BKey, headkey_not_found}}),
			     ok;
			 _Else ->
			     NewBKey = list_to_binary(re:replace(binary_to_list(BKey), "-", "_", [global, {return,list}])),
			     BValue = ebot_util:safe_list_to_binary(Value),
			     doc_set_value(
			       NewBKey, 
			       BValue,
			       Document)
		     end
	     end,
	     Doc,
	     Header_keys
	    ),
    doc_set_value( <<"http_returncode">>, Http_returncode, Doc2).

url_status(Db, Url, Options) ->
    Doc = open_url(Db, Url),
    url_doc_status(Doc, Options).

%%====================================================================
%% Internal functions
%%====================================================================

date_field_status(Date, Days) ->
    Now = calendar:datetime_to_gregorian_seconds( calendar:universal_time() ),
    Diff = Now - Date, 
    case Diff > Days * 86400 of
	true ->
	    obsolete;
	false ->
	    updated
    end.

doc_date_field_status(Doc, Field, Days) ->
    case Date = doc_get_value(Field, Doc) of
	0 ->
	    new;
	Date ->
	    date_field_status(Date, Days)
    end.   

doc_get_value(Key, Doc) ->
    case dict:find(Key, Doc) of
	{ok, Value} ->
	    Value;
	error ->
	    error
    end.

doc_set_value(Key, Value, Doc) ->
    dict:store(Key, Value, Doc).

ebot_header_keys()->
    [
 %    <<"content-length">>,
     <<"content-type">>
 %    <<"date">>,
 %    <<"last-modified">>,
 %    <<"server">>,
 %    <<"x-powered-by">>
    ].

%% removing_db_stardard_keys(Keys) ->
%%     lists:filter(
%%       fun(Key) ->
%% 	      case re:run(Key,<<"^_">>) of
%% 		  {match, _} ->
%% 		      false;
%% 		  nomatch ->
%% 		      true
%% 	      end
%%       end,
%%       Keys).

update_doc_increase_counter(Doc, Key) ->
    Value = doc_get_value(Key, Doc),
    update_doc_by_key_value(Doc, Key, Value + 1).

update_doc_timestamp_by_key(Doc, Key) ->
    Value = calendar:datetime_to_gregorian_seconds(calendar:universal_time()),
    update_doc_by_key_value(Doc, Key, Value).

update_doc_by_key_value(Doc, Key, Value) ->
    doc_set_value(Key, Value, Doc).

url_doc_header_status(Doc, Options) ->
    Result = doc_date_field_status(Doc, <<"ebot_head_visited">>, Options),
    {header, Result}.

url_doc_body_status(Doc, Options) ->
    case is_html_doc(Doc) of
	false ->
	    {body, skipped};
	true ->
	    Result = doc_date_field_status(Doc, <<"ebot_body_visited">>, Options),
	    {body, Result}
    end.

url_doc_status(not_found, _Options) ->
    not_found;
url_doc_status(Doc, Options) ->
    HeaderStatus = url_doc_header_status(Doc, Options),
    BodyStatus = url_doc_body_status(Doc, Options),
    {ok, HeaderStatus, BodyStatus}.
