About
=====

This is a STOMP client originally written by Ian Brown. I've simply taken the
liberty of wrapping it and providing it here for you.

stomp.erl is a simple client library for message brokers that support the STOMP 
protocol. It's usage is pretty straight forward, and below, I walk through a 
basic interaction with a broker and go into the public functions in greater 
detail. These examples will be using ActiveMQ as the broker. ActiveMQ is a free 
open source message broker, written in Java, that is pretty easy to install, 
set up, and run

Installation
============

Prerequisites
-------------
* erlang R14A
  - kernel, stdlib, sasl

Compilation
-----------

Build the source code by running::

  make

To clean::

  make clean

Usage
=====

Opening a connection
--------------------

The first thing we are going to do is open a connection to the broker. Underneath this call we will be opening a socket connection to the broker (stomp.erl uses the gen_tcp module bundled with Erlang) and sending some simple protocol messages to set up a session with the broker. As mentioned above, these examples are assuming that ActiveMQ is up and running in your local environment, with the STOMP handler enabled, and listening on the default port (61613).
The connect function takes four arguments (the broker's hostname or address, the port number, a login, and a passcode for authentication), and returns a Connection that we will be using throughout the subsequent exchanges::

  > Conn = stomp:connect("localhost", 61613, "", "").

Note that in this instance we do not require any authentication on the broker, and are passing in empty strings for the login and passcode parameters.

Sending messages
----------------

Ok, let's send a few messages to a queue (we will use a queue called "foobar" . . . ActiveMQ can create queues and topics "on demand" . . . there is no need to do any explicit administration or configuration, just send a message to the desired destination, and if it does not already exist, the ActiveMQ broker will automatically create it). To send a message, we will need to specify the underlying connection for transmission, the destination queue or topic, any headers we want to send (as a list of tuples), and the body of the message. Here is a simple example::

  > stomp:send(Conn, "/queue/foobar", [], "hello world").
  > stomp:send(Conn, "/queue/foobar", [{"priority","20"}], "we are specifying priority for this hello world").

Note that I am using the "priority" header in the example above to illustrate how to specify headers during a send operation. ActiveMQ does not currently re-order messages based on priority, though the header will be passed to the receiving client, so actions/prioritizing can occur within the consuming application.

Subscribing to a queue or topic
-------------------------------

Before we can recieve messages from the broker, we must register ourselves as a subscriber to a particular queue or topic. To do this, we will pass the connection we instantiated during the first step, along with a destination (the queue or topic we are interested in), and a list of two-tuples representing the names and values of any optional headers we wish to send::

  > stomp:subscribe("/queue/foobar", Conn, [{"ack", "client"}]).

We are now subscribed to the queue "foobar", and have told the broker to wait for an ack before removing retrieved messages from the queue.

Retrieving messages
-------------------

Now that we have subscribed to the queue "foobar", let's download those pending messages we sent earlier. To pull messages from a queue or topic, we can use the get_messages function. get_messages takes a connection as it's single argument, will pull down all available messages ("available" means available per broker and subscription policy, and not necessarily all pending messages), blocking if none are available. The return type is a list of messages, each message itself a list of 3 tuples: type, headers and message body. For example, here is what we get back if we call get_messages after sending the messages from the earlier step::

  > get_messages(Conn).
  [[{type,"MESSAGE"},
    {headers,[{"destination","/queue/foobar"},
            {"timestamp","1247956667243"},
            {"priority","0"},
            {"expires","0"},
            {"message-id",
             "ID:phosphorus-53442-1247930100064-2:5:-1:1:1"}]},
    {body,"hello world"}],
   [{type,"MESSAGE"},
    {headers,[{"destination","/queue/foobar"},
            {"timestamp","1247956684233"},
            {"priority","20"},
            {"expires","0"},
            {"message-id",
             "ID:phosphorus-53442-1247930100064-2:5:-1:1:2"}]},
    {body,"we are specifying priority for this hello world"}]]

Ack'ing messages
----------------

When we subscribed to the queue "foobar", you may have noticed that we passed in an optional header of the form	 {"ack", "client"}. This header tells the broker to not count a message as delivered until the client as explicitly acknowledged it's receipt...in fact if you examine the queue contents in the ActiveMQ broker console (http://localhost:8161/admin/browse.jsp?JMSDestination=foobar), you will see that the two messages we sent are still pending. In order to prevent another subscriber from picking up one of these messages, we will need to send a message acknowledging our receipt. To dod this, use the ack function, which takes a connection and a message id as parameters. The message id for each of the messages we have downloaded is present in the accompanying headers ({"message-id","ID:phosphorus-53442-1247930100064-2:5:-1:1:1"} and {"message-id","ID:phosphorus-53442-1247930100064-2:5:-1:1:2"}). Example::

  > stomp:ack(Conn, "ID:phosphorus-53442-1247930100064-2:5:-1:1:1").
  > stomp:ack(Conn, "ID:phosphorus-53442-1247930100064-2:5:-1:1:2").

Note, now if you check the queue, you will see these messages are no longer present, receipt by our subscriber having been confirmed.

Transactions
------------

STOMP provides transaction semantics for grouping send and ack messages with commit/rollback facilities. The begin_transaction, commit_transaction, and abort_transaction functions provide a means of sending those message types, along with the ack (Connection, MessageId, TransactionId) function and an optional "transaction" header for send operations. Examples::

  > stomp:begin_transaction(Conn, "MyUniqueTransactionIdBlahBlahBlah1234567890").
  > stomp:send(Conn, "/queue/foobar", [{"transaction", "MyUniqueTransactionIdBlahBlahBlah1234567890"}], "transactional hello world").

At this point, we have successfully sent a message to the broker, but if we inspect the queue contents in the ActiveMQ broker console (http://localhost:8161/admin/browse.jsp?JMSDestination=foobar), we will see that there are no pending messages . . . this is because we sent the last message as part of a transaction that has not been committed yet. To close the transaction, we use the commit_transaction function::

  > stomp:commit_transaction(Conn, "MyUniqueTransactionIdBlahBlahBlah1234567890").
  > stomp:get_messages(Conn).
  [[{type,"MESSAGE"},
    {headers,[{"destination","/queue/foobar"},
            {"transaction",
             "MyUniqueTransactionIdBlahBlahBlah1234567890"},
            {"timestamp","1248013136111"},
            {"priority","0"},
            {"expires","0"},
            {"message-id",
             "ID:phosphorus-53442-1247930100064-2:7:-1:1:5"}]},
    {body,"transactional hello world"}]]

on_message
----------

stomp.erl also provides an "on message" handler, that allows you to pass in a function that will be called on each recieved message. Unlike get_messages it will block continuously (get_messages will return after getting all available messages), waiting for messages to arrive on the queue. Example::

  > stomp:send(Conn, "/queue/foobar", [], "message one").
  > stomp:send(Conn, "/queue/foobar", [], "message two").
  > stomp:send(Conn, "/queue/foobar", [], "message three").	
  > MyFunction=fun([_, _, {_, X}]) -> io:fwrite("message ~s ~n", [X]) end.
  #Fun<erl_eval.6.13229925>
  > stomp:on_message(MyFunction, Conn).
  message message one 
  message message two 
  message message three

Copyright and License
=====================

Copyright 2010 Bob.sh

Copyright 2009 Ian Brown

The license for this code is undecided as yet. Assume nothing.
