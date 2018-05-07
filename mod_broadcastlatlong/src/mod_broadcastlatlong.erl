-module(mod_broadcastlatlong).
-behaviour(gen_mod).

-include("ejabberd.hrl").
-include("logger.hrl").
-include("jlib.hrl").

%% gen_mod API callbacks
-export([start/2, stop/1]).
-export([broadcast/2]).
-export([echoback/1]).

start(_Host, _Opts) ->
    ?INFO_MSG("mod_broadcastlatlong working now", []),
	ejabberd_hooks:add(filter_packet, global, ?MODULE, echoback, 0).  

stop(_Host) ->
	ejabberd_hooks:remove(filter_packet, global, ?MODULE, echoback, 0),
    ?INFO_MSG("mod_broadcastlatlong stopped working", []),
    ok.
	
broadcast(From,To) ->
	
	%% Parse From object and extract address to send message
	FirstElement = element(2,From),
	SecondElement = element(3,From),
	
	FirstElementString  = binary_to_list(FirstElement),	
	SecondElementString = binary_to_list(SecondElement),	
	
	FirstPart = string:concat(FirstElementString,"@"),
	ToSendString = string:concat(FirstPart,SecondElementString),
	
	ToSend = list_to_binary(ToSendString),
	
	%% Send request to MySql server
	{Type, Result} = mysql:start_link(p1, "localhost", "USERNAMEHERE", "PASSWORDHERE", "DBNAMEHERE"),
	mysql:connect(p1, "localhost", undefined, "USERNAMEHERE", "PASSWORDHERE", "DBNAMEHERE", true),
	MysqlResult = mysql:fetch(p1, [<<"SELECT * FROM location2 WHERE timestamp != 'IDLE'">>]),
	MysqlResultExracted = element(2,MysqlResult),
	AllRows = mysql:get_result_rows(MysqlResultExracted),
	
	%% Reconstruct result as a list, to send it back to client
	MessageBodyString = [ [ <<"{">> , list_to_binary(Id) , <<",">> , list_to_binary(TimeStamp), <<",">> , list_to_binary(StartTime), <<",">> , list_to_binary(Lat),<<",">> , list_to_binary(Lon) ,  <<"};">> ] || [Id, TimeStamp, StartTime, Lat, Lon] <- AllRows],

	MessageBodyStringSecond = string:concat("@",MessageBodyString),
	MessageBodyStringFinal  = string:concat("$+?broadcastResult:@",MessageBodyStringSecond),
	
	%% Convert to String
	MessageBodyBinary = list_to_binary(MessageBodyStringFinal),
	
	%% Construct message
	MessageToSend = #xmlel{name    = <<"message">>,
			  attrs    = [{<<"to">>, ToSend},{<<"type">>, <<"groupchat">>} ],
			  children = [#xmlel{name = <<"body">>,
							attrs = [], children = [{xmlcdata,MessageBodyBinary}] }]},

	%% Broadcast message
	ejabberd_router:route(From,To,MessageToSend),
	mysql:stop(),	
    error_logger:info_msg("Results ~p~n", [AllRows]).
	

echoback({From, To, XML} = Packet) ->
	
	%% if packet is a chat message
	case xml:get_subtag(XML, <<"body">>) of	
		false ->
			ok;
		_ ->		
			%% Get body from XML packet
			BodyFromXML = xml:get_tag_cdata(xml:get_subtag(XML, <<"body">>)),
			
			%% Convert binary to String
			BodyString = binary_to_list(BodyFromXML),		
			
			%% if it starts with $+?requestBusInfo
			case string:str(BodyString,"$+?requestBusInfo") of
				1 ->					
					%% Apply timer that calls broadcast() method every 20 seconds
					timer:apply_interval(20000, mod_broadcastlatlong, broadcast, [From,To]);
				_ ->
					ok
			end
			
			
	end,
	
	Packet.