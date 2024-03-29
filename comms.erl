-module(comms).
-export([start/0, publisher/1, broker/0, consumer/0, monitor/0]).

start() ->
    Monitor = spawn(comms, monitor, []),
    BrokerPid = spawn(comms, broker, []),
    ConsumerPid = spawn(comms, consumer, []),
    Publishers = [spawn(comms, publisher, [I]) || I <- lists:seq(1, 6)],
    register(monitor, Monitor),
    Monitor ! {publishers, Publishers},
    Monitor ! {broker, BrokerPid},
    Monitor ! {consumer, ConsumerPid},
    ok.

publisher(Id) ->
    loop_publisher(Id, 0).

loop_publisher(Id, MsgCount) ->
    RandomNum = rand:uniform(11),
    case RandomNum of
        11 -> 
            io:format("Publisher ~p: Ending process (for value 11).~n", [Id]),
            monitor ! {publisher_ended, Id};
        _ ->
            io:format("Publisher ~p: Sent [~p,~p] to broker.~n", [Id, Id, RandomNum]),
            monitor ! {monitor, {message, Id, RandomNum}},
            timer:sleep(Id * 10),
            loop_publisher(Id, MsgCount + 1)
    end.

broker() ->
    loop_broker([]).

loop_broker(Messages) ->
    receive
        {message, Id, Value} ->
            UpdatedMessages = [Value | Messages],
            if
                length(UpdatedMessages) == 6 ->
                    Consumer ! {broker_message, UpdatedMessages},
                    io:format("Broker: Sending message ~p~n", [UpdatedMessages]),
                    loop_broker([]);
                true ->
                    loop_broker(UpdatedMessages)
            end;
        stop ->
            io:format("Broker: Ending monitor, all publishers, and self.~n")
    end.

consumer() ->
    loop_consumer([], []).

loop_consumer(ReceivedData, GeneratedData) ->
    receive
        {broker_message, Message} ->
            Sum = lists:sum(Message),
            io:format("Consumer: Received message ~p sum ~p~n", [Message, Sum]),
            ReceivedData1 = [Sum | ReceivedData],
            Generated = [rand:uniform(10) || _ <- lists:seq(1, 6)],
            SumGenerated = lists:sum(Generated),
            io:format("Consumer: Generated value ~p sum ~p~n", [Generated, SumGenerated]),
            GeneratedData1 = [SumGenerated | GeneratedData],
            if
                length(ReceivedData1) == 100 ->
                    % Calculate and display mean and standard deviation for ReceivedData1 and GeneratedData1
                    io:format("Consumer: Process ended.~n");
                true ->
                    loop_consumer(ReceivedData1, GeneratedData1)
            end
    end.

monitor() ->
    loop_monitor(undefined, undefined, undefined, []).

loop_monitor(Broker, Consumer, Publishers) ->
    receive
        {publisher_ended, Id} ->
            NewPublisher = spawn(comms, publisher, [Id]),
            io:format("Monitor: Restarting Publisher ~p.~n", [Id]),
            NewPublishers = lists:keystore(Id, 1, Publishers, {Id, NewPublisher}),
            loop_monitor(Broker, Consumer, NewPublishers);
        stop ->
            io:format("Monitor: Stopping.~n");
        {broker, Pid} ->
            loop_monitor(Pid, Consumer, Publishers);
        {consumer, Pid} ->
            loop_monitor(Broker, Pid, Publishers);
        {publishers, Pids} ->
            PublishersList = lists:zip(lists:seq(1, length(Pids)), Pids),
            loop_monitor(Broker, Consumer, PublishersList)
    end.
