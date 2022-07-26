%%%-----------------------------------------------------------------------------
%%% @doc Cowboy REST handler for handling status requests sent to
%%%      `api/[VERSION]/state'.
%%% @end
%%%-----------------------------------------------------------------------------

-module(xss_state_rest_handler).
-include("x11_sentinel_server.hrl").
-behaviour(cowboy_rest).

%%%=============================================================================
%%% Exports
%%%=============================================================================

%% `cowboy_handler' callbacks
-export([init/2]).

%% `cowboy_rest' callbacks
-export([allowed_methods/2,
         content_types_provided/2,
         valid_entity_length/2]).

%% Configured, custom callbacks to handle `cowboy_rest' calls
-export([provide_json/2]).

%%%=============================================================================
%%% Types
%%%=============================================================================

-type state() :: #{}.

%%%=============================================================================
%%% Macros
%%%=============================================================================

%% Maximum allowed length of a request
-define(DEFAULT_REQUEST_MAX_LENGTH, (2*1024)). % 2KB

%%%=============================================================================
%%% Exported functions
%%%=============================================================================

%%%-----------------------------------------------------------------------------
%%% `cowboy_handler' callbacks
%%%-----------------------------------------------------------------------------

%%------------------------------------------------------------------------------
%% @doc Initialize handler.
%% @end
%%------------------------------------------------------------------------------
-spec init(Request, State) -> {cowboy_rest, Request, State} when
      Request :: cowboy_req:req(),
      State :: state().
init(Request, #{} = State) ->
    {cowboy_rest, Request, State}.

%%%-----------------------------------------------------------------------------
%%% `cowboy_rest' callbacks
%%%-----------------------------------------------------------------------------

%%------------------------------------------------------------------------------
%% @doc `allowed_methods' callback.
%% @end
%%------------------------------------------------------------------------------
-spec allowed_methods(Request, State) -> {Methods, Request, State} when
      Request :: cowboy_req:req(),
      State :: state(),
      Methods :: [binary()].
allowed_methods(Request, State) ->
    {[<<"GET">>], Request, State}.

%%------------------------------------------------------------------------------
%% @doc `content_types_provided' callback.
%% @end
%%------------------------------------------------------------------------------
-spec content_types_provided(Request, State) -> Result when
      Request :: cowboy_req:req(),
      State :: state(),
      Result :: {[{ContentType, Callback}], Request, State},
      ContentType :: binary(),
      Callback :: atom().
content_types_provided(Request, State) ->
    {[{<<"application/json">>, provide_json}], Request, State}.

%%------------------------------------------------------------------------------
%% @doc `valid_entity_length' callback.
%% @end
%%------------------------------------------------------------------------------
-spec valid_entity_length(Request, State) -> {Result, Request, State} when
      Request :: cowboy_req:req(),
      State :: state(),
      Result :: boolean().
valid_entity_length(Request, State) ->
    MaxLength = application:get_env(?APPLICATION,
                                    request_max_length,
                                    ?DEFAULT_REQUEST_MAX_LENGTH),
    case
        cowboy_req:body_length(Request)
    of
        Length when Length < MaxLength ->
            {true, Request, State};
        _ ->
            {false, Request, State}
    end.

%%%-----------------------------------------------------------------------------
%%% Configured custom handler
%%%-----------------------------------------------------------------------------

%%------------------------------------------------------------------------------
%% @doc `ProvideCallback' handler for JSON requests.
%% @end
%%------------------------------------------------------------------------------
-spec provide_json(Request, State) -> {ResponseBody, Request, State} when
      Request :: cowboy_req:req(),
      State :: state(),
      ResponseBody :: iodata().
provide_json(Request1, State) ->
    Request2 = xss_utils:add_cors_headers(Request1),
    {jiffy:encode(#{result => ok}), Request2, State}.
