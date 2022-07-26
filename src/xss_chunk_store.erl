%%%-----------------------------------------------------------------------------
%%% @doc This module contains API functions to execute queries on the database
%%%      related to the {@link xss_chunk} model.
%%% @end
%%%-----------------------------------------------------------------------------

-module(xss_chunk_store).
-include("x11_sentinel_server.hrl").

%%%=============================================================================
%%% Exports
%%%=============================================================================

-export([select_chunk_by_stream_id_and_sequence_number/2,
         select_chunks_by_user_id/1,
         select_sequence_numbers_by_stream_id/1,
         select_event_count_by_stream_id/1,
         insert_chunk/1,
         soft_delete_chunk_by_stream_id_and_sequence_number/2]).

%%%=============================================================================
%%% API functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Get a chunk from the database by the `stream_id' and `sequence_number'
%%      fields.
%% @end
%%------------------------------------------------------------------------------
-spec select_chunk_by_stream_id_and_sequence_number(
          StreamId, SequenceNumber) -> Result when
      StreamId :: xss_stream:stream_id(),
      SequenceNumber :: xss_chunk:sequence_number(),
      Result :: {ok, xss_chunk:chunk()} | {error, Reason},
      Reason :: any().
select_chunk_by_stream_id_and_sequence_number(StreamId, SequenceNumber) ->
    case
      xss_database_server:execute(select_chunk_by_stream_id_and_sequence_number,
                                  [StreamId, SequenceNumber])
    of
        {ok, _Columns, []} ->
            {error, #{reason => chunk_not_found,
                      stream_id => StreamId,
                      sequence_number => SequenceNumber}};
        {ok, _Columns, [Row | _Rest]} ->
            {ok, parse_db_row(Row)}
    end.

%%------------------------------------------------------------------------------
%% @doc Get all chunks from the database which belong to the given `user_id'
%%      field.
%% @end
%%------------------------------------------------------------------------------
-spec select_chunks_by_user_id(UserId) -> Result when
      UserId :: xss_user:user_id(),
      Result :: {ok, [xss_chunk:chunk()]}.
select_chunks_by_user_id(UserId) ->
    case
      xss_database_server:execute(select_chunks_by_user_id, [UserId])
    of
        {ok, _Columns, []} ->
            {ok, []};
        {ok, _Columns, Rows} ->
            {ok, lists:map(fun parse_db_row/1, Rows)}
    end.

%%------------------------------------------------------------------------------
%% @doc Get all chunk sequence numbers from the database which belong to the
%%      given stream by the `stream_id' field.
%% @end
%%------------------------------------------------------------------------------
-spec select_sequence_numbers_by_stream_id(StreamId) -> Result when
      StreamId :: xss_stream:stream_id(),
      Result :: {ok, [xss_chunk:sequence_number()]}.
select_sequence_numbers_by_stream_id(StreamId) ->
    case
      xss_database_server:execute(select_sequence_numbers_by_stream_id, [StreamId])
    of
        {ok, _Columns, []} ->
            {ok, []};
        {ok, _Columns, Rows} ->
            {ok, lists:map(fun ({SequenceNumber}) -> SequenceNumber end, Rows)}
    end.

%%------------------------------------------------------------------------------
%% @doc Get all chunk sequence numbers from the database which belong to the
%%      given stream by the `stream_id' field.
%% @end
%%------------------------------------------------------------------------------
-spec select_event_count_by_stream_id(StreamId) -> Result when
      StreamId :: xss_stream:stream_id(),
      Result :: {ok, non_neg_integer()}.
select_event_count_by_stream_id(StreamId) ->
    case
      xss_database_server:execute(select_event_count_by_stream_id, [StreamId])
    of
        {ok, _Columns, [{null}]} ->
            {ok, 0};
        {ok, _Columns, [{Value}]} ->
            {ok, Value}
    end.

%%------------------------------------------------------------------------------
%% @doc Insert a new chunk into the database.
%% @end
%%------------------------------------------------------------------------------
-spec insert_chunk(Chunk) -> Result when
      Chunk :: xss_chunk:chunk(),
      Result :: {ok, RowsEffected} | {error, Reason},
      RowsEffected :: integer(),
      Reason :: any().
insert_chunk(#{metadata :=
              #{stream_id := StreamId,
                sequence_number := SequenceNumber,
                session_id := SessionId,
                user_id := UserId,
                epoch := #{unit := EpochUnit,
                           value := EpochValue}},
          submitted_at := SubmittedAt,
          real_ip_address := RealIpAddress,
          peer_ip_address := PeerIpAddress,
          referer := Referer,
          chunk := Chunk,
          created_at := undefined,
          updated_at := undefined}) ->
    Now = xss_utils:xss_timestamp_to_epgsql_timestamp(xss_utils:now()),
    {ok, RealIp} = inet:parse_address(binary:bin_to_list(RealIpAddress)),
    {ok, PeerIp} = inet:parse_address(binary:bin_to_list(PeerIpAddress)),
    xss_database_server:execute(insert_chunk,
        [StreamId,
         SequenceNumber,
         SessionId,
         UserId,
         EpochUnit,
         EpochValue,
         xss_utils:xss_timestamp_to_epgsql_timestamp(SubmittedAt),
         RealIp,
         PeerIp,
         Referer,
         jiffy:encode(Chunk),
         Now,
         Now]).

%%------------------------------------------------------------------------------
%% @doc Soft delete chunk by setting the `deleted_at' field.
%% @end
%%------------------------------------------------------------------------------
-spec soft_delete_chunk_by_stream_id_and_sequence_number(
          StreamId, SequenceNumber) -> Result when
      StreamId :: xss_stream:stream_id(),
      SequenceNumber :: xss_chunk:sequence_number(),
      Result :: {ok, RowsEffected} | {error, Reason},
      RowsEffected :: integer(),
      Reason :: any().
soft_delete_chunk_by_stream_id_and_sequence_number(StreamId, SequenceNumber) ->
    Now = xss_utils:xss_timestamp_to_epgsql_timestamp(xss_utils:now()),
    xss_database_server:execute(
        soft_delete_chunk_by_stream_id_and_sequence_number,
        [Now, Now, StreamId, SequenceNumber]).

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%-----------------------------------------------------------------------------
%% @doc Parse a raw database entry into a {@link xss_chunk} model entity.
%% @end
%%-----------------------------------------------------------------------------
-spec parse_db_row({StreamId,
                   SequenceNumber,
                   SessionId,
                   UserId,
                   EpochUnit,
                   EpochValue,
                   SubmittedAt,
                   RealIpAddress,
                   PeerIpAddress,
                   Referer,
                   Chunk,
                   CreatedAt,
                   UpdatedAt}) -> ParsedChunk when
      StreamId :: xss_stream:stream_id(),
      SequenceNumber :: xss_chunk:sequence_number(),
      SessionId :: xss_session:session_id(),
      UserId :: xss_user:user_id(),
      EpochUnit :: binary(),
      EpochValue :: non_neg_integer(),
      SubmittedAt :: xss_utils:epgsql_timestamp() | null,
      RealIpAddress :: inet:ip_address(),
      PeerIpAddress :: inet:ip_address(),
      Referer :: binary(),
      Chunk :: [xss_chunk:event()],
      CreatedAt :: xss_utils:epgsql_timestamp() | null,
      UpdatedAt :: xss_utils:epgsql_timestamp() | null,
      ParsedChunk :: xss_chunk:chunk().
parse_db_row({StreamId,
              SequenceNumber,
              SessionId,
              UserId,
              EpochUnit,
              EpochValue,
              SubmittedAt,
              RealIpAddress,
              PeerIpAddress,
              Referer,
              Chunk,
              CreatedAt,
              UpdatedAt}) ->
    #{metadata =>
          #{stream_id => StreamId,
            sequence_number => SequenceNumber,
            session_id => SessionId,
            user_id => UserId,
            epoch => #{unit => EpochUnit, value => EpochValue}},
      submitted_at => xss_utils:epgsql_timestamp_to_xss_timestamp(SubmittedAt),
      real_ip_address => list_to_binary(inet:ntoa(RealIpAddress)),
      peer_ip_address => list_to_binary(inet:ntoa(PeerIpAddress)),
      referer => Referer,
      chunk => jiffy:decode(Chunk, [return_maps]),
      created_at => xss_utils:epgsql_timestamp_to_xss_timestamp(CreatedAt),
      updated_at => xss_utils:epgsql_timestamp_to_xss_timestamp(UpdatedAt)}.
