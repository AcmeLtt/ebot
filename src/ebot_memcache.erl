%%%-------------------------------------------------------------------
%%% File    : ebot_memcache.erl
%%% Author  : matteo <<matteo.redaelli@@libero.it>
%%% Description : 
%%%
%%% Created :  4 Oct 2009 by matteo <matteo@redaelli.org>
%%%-------------------------------------------------------------------
-module(ebot_memcache).
-author("matteo.redaelli@@libero.it").
-define(SERVER, ?MODULE).

-behaviour(gen_server).

%% API
-export([
	 add_candidated_url/1,
	 add_visited_url/1,
	 info/0,
	 is_visited_url/1,
	 show_candidated_urls/0,
	 show_visited_urls/0,
	 start_link/0,
	 statistics/0
	]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-record(state, {
	  config = [],
	  counter = 0,
	  candidated_urls = queue:new(),
	  visited_urls = queue:new()
	 }).

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link() -> {ok,Pid} | ignore | {error,Error}
%% Description: Starts the server
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

add_candidated_url(Url) ->
    gen_server:cast(?MODULE, {add_candidated_url, Url}).
add_visited_url(Url) ->
    gen_server:cast(?MODULE, {add_visited_url, Url}).
is_visited_url(Url) ->
    gen_server:call(?MODULE, {is_visited_url, Url}).

info() ->
    gen_server:call(?MODULE, {info}).

show_candidated_urls() ->
    gen_server:call(?MODULE, {show_candidated_urls}).
show_visited_urls() ->
    gen_server:call(?MODULE, {show_visited_urls}).
statistics() ->
    gen_server:call(?MODULE, {statistics}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
%%--------------------------------------------------------------------
init([]) ->

%%	error_logger:error_report({?MODULE, ?LINE,
%%                                       {applicazione, partita}}),
%%	error_logger:error_msg("ebot demo webmachine error: "),
%%	error_logger:info_msg("ebot demo webmachine info: "),

    case ebot_util:load_settings(?MODULE) of
	{ok, Config} ->
	    {ok, #state{config=Config}};
	_Else ->
	    {error, cannot_load_configuration}
    end.

%%--------------------------------------------------------------------
%% Function: %% handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% Description: Handling call messages
%%--------------------------------------------------------------------;

handle_call({is_visited_url, Url}, _From, State) ->
    Visited = State#state.visited_urls,
    Result = queue:member(Url, Visited),
    {reply, Result, State};

handle_call({info}, _From, State) ->
    Reply = ebot_util:info(State#state.config),
    {reply, Reply, State};

handle_call({show_candidated_urls}, _From, State) ->
    Reply = show_queue(State#state.candidated_urls),
    {reply, Reply, State};

handle_call({show_visited_urls}, _From, State) ->
    Reply = show_queue(State#state.visited_urls),
    {reply, Reply, State};

handle_call({statistics}, _From, State) ->
    Reply = atom_to_list(?MODULE),
    NewState = State,
    {reply, Reply, NewState};

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% Description: Handling cast messages
%%--------------------------------------------------------------------
handle_cast({add_candidated_url, Url}, State) ->
    NewState = add_candidated_url(Url, State),
    {noreply, NewState};

handle_cast({add_visited_url, Url}, State) ->
    Queue =  State#state.visited_urls,
    case queue:member(Url, Queue) of
	true  ->
	    NewState = State;
	false ->
	    NewState = State#state{
			 counter = State#state.counter + 1,
			 visited_urls = queue:in(Url, Queue)
			}
    end,
    {noreply, NewState};


handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------

get_config(Option, State) ->
    proplists:get_value(Option, State#state.config).

add_candidated_url(Url, State) ->
    Queue =  State#state.candidated_urls,
    case queue:member(Url, Queue) of
	true  ->
	    NewState = State;
	false ->
	    NewState = State#state{
			 candidated_urls = queue:in(Url, Queue)
			}
    end,
    ebot_amqp:add_candidated_url(Url),
    NewState.



show_queue(Q) ->
    List = lists:map(
	     fun binary_to_list/1,
	     queue:to_list( Q)
	    ),
    string:join( List, ", ").
