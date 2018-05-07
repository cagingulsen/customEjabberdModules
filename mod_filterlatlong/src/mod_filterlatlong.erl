-module(mod_filterlatlong).

-behaviour(gen_mod).

-include("ejabberd.hrl").
-include("logger.hrl").
-include("jlib.hrl").

%% gen_mod API callbacks

-export([start/2, stop/1]).
-export([on_filter_packet/1]).
-export([processLocation/1]).

start(_Host, _Opts) ->
    ?INFO_MSG("mod_filterlatlong working now", []),
	ejabberd_hooks:add(filter_packet, global, ?MODULE, on_filter_packet, 0).
	
stop(_Host) ->
    ?INFO_MSG("mod_filterlatlong stopped working", []),
    ok.

on_filter_packet({From, To, XML} = Packet) ->

	case xml:get_subtag(XML, <<"body">>) of
		false ->
			ok;
		_ ->		
			%% Get body of the packet
			MessageBody = xml:get_tag_cdata(xml:get_subtag(XML, <<"body">>)),
			MessageBodyString = binary_to_list(MessageBody),		

			%% If message body starts with $+?simulator:
			case string:str(MessageBodyString,"$+?simulator:") of
				1 ->
					%% Extract latitude, longitude and bus id info from message body 
					LengthOfString = string:len(MessageBodyString),
					GpsDataString = string:substr(MessageBodyString,14,LengthOfString),
					GpsDataList = string:tokens(GpsDataString,";"),
					
					{Type, Result} = mysql:start_link(p1, "localhost", "USERNAME", "PASSWORD", "DBNAME"),
					mysql:connect(p1, "localhost", undefined, "USERNAME", "PASSWORD", "DBNAME", true),
	
					lists:foreach(fun(X) -> processLocation(X) end, GpsDataList),	
					
					mysql:stop();
				_ ->
					ok
			end,

			%% If body starts with $+?plannerRequest: string
			case string:str(MessageBodyString,"$+?plannerRequest:") of
				1 ->					
					LengthOfString2 = string:len(MessageBodyString),
					Values = string:substr(MessageBodyString,19,LengthOfString2),

					%% Send Values to HTTP Server in other words RTEM Module
					inets:start(),
					URL = "http://YOURURL.COM",

					{ok, {Status, Head, Body}} = httpc:request(get,{URL,[{"values",Values}]}, [], []),	
					
					%% Goal is to send Http Server response to the android application
					
					%% Parse the address of an android application
					UserName = element(2,From),
					
					%% Make string
					StrUserName = binary_to_list(UserName),	
					
					%% Create a final address for the android client
					FinalAddress = string:concat(StrUserName, "@example.com"),
					
					%% Make response binary
					ResponseForAndroid = list_to_binary(Body),

					Data = {xmlel,<<"message">>,
				       [{<<"xml:lang">>,<<"en">>},
					{<<"type">>,<<"chat">>},
					{<<"to">>,FinalAddress},
					{<<"id">>,<<"aad9a">>}],
				       [{xmlcdata,<<"\n">>},
					{xmlel,<<"body">>,[],[{xmlcdata,ResponseForAndroid}]},
					{xmlcdata,<<"\n">>},
					{xmlel,<<"active">>,
					       [{<<"xmlns">>,<<"http://jabber.org/protocol/chatstates">>}],
					       []},
					{xmlcdata,<<"\n">>}]},
					
					ejabberd_router:route(To,From,Data);
				_ ->
					ok
			end
	end,

    Packet.
	
	
processLocation(GpsString) ->

    [LineId, TimeStamp, StartTime, Ltitude, Lngitude] = string:tokens(GpsString, ","),
	
	%% ?INFO_MSG("LineId: ~p~n",[LineId]),
	%% ?INFO_MSG("TimeStamp: ~p~n",[TimeStamp]),	
	%% ?INFO_MSG("StartTime: ~p~n",[StartTime]),
	%% ?INFO_MSG("Lat: ~p~n",[Ltitude]),
	%% ?INFO_MSG("Lon: ~p~n",[Lngitude]),

	%% Send latitude and longitude data to MySql Server
	mysql:fetch(p1, [<<"UPDATE location2 l SET l.lat = '">>, Ltitude, <<"' , l.lon = '">> , Lngitude , <<"' , l.timestamp = '">> , TimeStamp , <<"' WHERE l.lineId = '">> , LineId , <<"' and l.startTime = '">> , StartTime, <<"'">>]),
	
	ok.