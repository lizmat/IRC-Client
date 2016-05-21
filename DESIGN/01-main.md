# PURPOSE

The purpose of IRC::Client is to provide serve as a fully-functional IRC
client that--unlike programs like HexChat or mIRC--provide a programmatic
interface to IRC. So, for example, to send a message to a channel, instead
of typing a message in a message box and pressing ENTER, a method is called
and given a string.

Naturally, such an interface provides vast abilities to automate interactions
with IRC or implement a human-friendly interface, such as HexChat or mIRC.

# GOALS

An implementation must achieve these goals:

## Ease of Use

For basic use, such as a bot that responds to triggers said in channel,
the details of the IRC protocol must be as invisible as possible. Just as any
user can install HexChat and join a channel and talk, similar usability has
to be achieved by the implementation.

As an example, a HexChat user can glance at the user list or channel topic
without explicitly issuing `NAMES` or `TOPIC` IRC commands. The implementation
should thus provide similar simplicity and provide a userlist or topic
via a convenient method rather than explicit method to send the appropriate
commands and the requirement of listening for the server response events.

## Client-Generated Events

The implementation must allow the users of the code to emit IRC and custom
events. For example, given plugins A and B, with A performing processing
first, plugin A can mark all `NOTICE` IRC events as handled and emit them
as `PRIVMSG` events instead. From the point of view of second plugin B, no
`NOTICE` commands ever happen (as they arrive to it as `PRIVMSG`).

Similarly, plugin A can choose to emit custom event `FOOBAR` instead of
`PRIVMSG`, to which plugin B can choose to respond to.

## Possibility of Non-Blocking Code

The implementation must allow the user to perform responses to events in
a non-blocking manner if they choose to.

# DESIGN

The implementation consists of Core code responsible for maintaining the
state of the connected client, parsing of server messages, and sending
essential messages, as well as relating messages to and from plugins.

The implementation distribution may also include several plugins that may
be commonly needed by users. Such plugins are not enabled by default and
the user must request their inclusion with code.

## Core

### Client Object

Client Object represents a connected IRC client and is aware of and can
manipulate its state, such as disconnecting, joining or parting a channel,
or sending messages.

A program may have multiple Client Objects, but each of them can be connected
only to one IRC server.

A relevant Client Object must be easily accessible to the user of the
implementation. This includes user's plugins responsible for handling
events.

###

## Message Delivery

An event listener receives the event message in the form of an object.
The object must provide all the relevant information about the source
and content of the message.

The message object's attributes must be mutable, and where appropriate,
it must provide the means to send the message back to the originator
of the message. For example, here's a potential implementation of
`PRIVMSG` handler that receives the message object:

    use IRC::Client::Plugin;
    unit Plugin::Foo is IRC::Client::Plugin;

    method irc-privmsg ($msg) {
        return IRC_NOT_HANDLED unless $msg.channel eq '#perl6';
        $msg.what = "Nice to meet you, $msg.who()";
        $msg.send;
    }

The message object should include a means to access the Client Object to
perform operations best suited for it and not the message object. Here is
a possible implementation to re-emit a `NOTICE` message sent to channel
`#perl6` as a `PRIVMSG` message.

    method irc-notice ($msg) {
        if $msg.channel eq '#perl6' {
            $msg.how = 'PRIVMSG';
            $msg.irc.emit: 'PRIVMSG', $msg;
        }

        return IRC_NOT_HANDLED;
    }
