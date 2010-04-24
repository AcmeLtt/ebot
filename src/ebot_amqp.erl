%%%-------------------------------------------------------------------
%%% File    : ebot_amqp.erl
%%% Author  : matteo <matteo@pirelli.com>
%%% Description : 
%%%
%%% Created : 23 Apr 2010 by matteo <matteo@pirelli.com>
%%%-------------------------------------------------------------------
-module(ebot_amqp).

-author("matteo.redaelli@@libero.it").

-define(SERVER, ?MODULE).
-define(EBOT_EXCHANGE, <<"EBOT">>).
-define(EBOT_QUEUE_URL_CANDIDATES, <<"EBOT_QUEUE_URL_CANDIDATES">>).
-define(EBOT_KEY_URL_CANDIDATES, <<"ebot.url.candidates">>).
-define(EBOT_KEY_URL_PROCESSED, <<"ebot.url.processed">>).
-define(EBOT_KEY_URL_REFUSED, <<"ebot.url.refused">>).
-define(TIMEOUT, 10000).

-behaviour(gen_server).

-include("../deps/rabbitmq-erlang-client/include/amqp_client.hrl").


%% API
-export([
	 start_link/0,
	 add_candidated_url/1,
	 add_refused_url/1,
	 get_candidated_url/0
	]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-record(state, {
	  connection,
	  channel,
	  exchange = ?EBOT_EXCHANGE
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

add_refused_url(Url) ->
    gen_server:cast(?MODULE, {add_refused_url, Url}).

get_candidated_url() ->
    gen_server:call(?MODULE, {get_candidated_url}).

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
    case ampq_connect_and_get_channel() of
	{ok, {Connection, Channel}} ->
	    amqp_setup_consumer(
	      Channel,
	      ?EBOT_QUEUE_URL_CANDIDATES, 
	      ?EBOT_EXCHANGE,
	      ?EBOT_KEY_URL_CANDIDATES
	     ),
	    {ok, #state{
	       channel = Channel,
	       connection = Connection
	      }
	    };
	_Else ->
	    error
    end.

%%--------------------------------------------------------------------
%% Function: %% handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% Description: Handling call messages
%%--------------------------------------------------------------------

handle_call({get_candidated_url}, _From, State) ->
    Channel =  State#state.channel,

    Reply = amqp_basic_get_message(Channel, ?EBOT_QUEUE_URL_CANDIDATES),

    {reply, Reply, State};

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
    amqp_send_message(?EBOT_KEY_URL_CANDIDATES, Url, State),
    {noreply, State};

handle_cast({add_refused_url, Url}, State) ->
    amqp_send_message(?EBOT_KEY_URL_REFUSED, Url, State),
    {noreply, State};

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
terminate(_Reason, State) ->
    Connection = State#state.connection,
    Channel =  State#state.channel,
    amqp_channel:close(Channel),
    amqp_connection:close(Connection),
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

ampq_connect_and_get_channel() ->
    %% Start a connection to the server
    Connection = amqp_connection:start_network(),

    %% Once you have a connection to the server, you can start an AMQP channel

    %% TODO : verify 

    Channel = amqp_connection:open_channel(Connection),
    ExchangeDeclare = #'exchange.declare'{
      exchange = ?EBOT_EXCHANGE, 
      type = <<"topic">>
      %% uncomment the following row if you want a durable exchange
      %% , durable = true
     },
    #'exchange.declare_ok'{} = amqp_channel:call(Channel, ExchangeDeclare),
    {ok, {Connection,Channel}}.

amqp_basic_get_message(Channel, Queue) ->
    {#'basic.get_ok'{}, Content}
	= amqp_channel:call(Channel, 
			    #'basic.get'{queue = Queue, no_ack = true}),
    #amqp_msg{payload = Payload} = Content,
    io:format("Payload received: ~p~n", [Payload]),
    Payload.

amqp_send_message(RoutingKey, Payload, State) ->
    Channel =  State#state.channel,
    Exchange =  State#state.exchange,
    BasicPublish = #'basic.publish'{exchange = Exchange, routing_key = RoutingKey},

    Msg = #amqp_msg{
      payload = Payload
      %% uncomment the following row if you want a durable message
      %%, props = #'P_basic'{delivery_mode=2}
     },
    case Result = amqp_channel:cast(Channel, BasicPublish, _MsgPayload = Msg) of
	ok ->
	    io:format("amqp_send_message: ok: Key=~p, Payload=~p~n", 
		      [RoutingKey,Payload]);
	else ->
	    io:format("amqp_send_message: failed: Key=~p, Payload=~p~n", 
		      [RoutingKey,Payload])
    end,
    Result.
    
amqp_setup_consumer(Channel, Q, X, Key) ->
    QueueDeclare = #'queue.declare'{queue=Q
				    %%, durable=true
				   },
    #'queue.declare_ok'{queue = Q,
                        message_count = MessageCount,
                        consumer_count = ConsumerCount}
	= amqp_channel:call(Channel, QueueDeclare),
    
    log(queue,Q),
    log(message_count,MessageCount),
    log(consumer_count,ConsumerCount),

    QueueBind = #'queue.bind'{queue = Q,
                              exchange = X,
                              routing_key = Key},
    #'queue.bind_ok'{} = amqp_channel:call(Channel, QueueBind).

log(Key,Value) ->
    io:format("~p: ~p~n",[Key,Value]).
