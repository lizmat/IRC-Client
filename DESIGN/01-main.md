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

### Message Delivery

An event listener is defined by a method in a plugin class. The name
of the method starts with `irc-` and followed by the lowercase name of the
event. User-defined events follow the same pattern, except they start with
`irc-custom-`:

```perl6
    use IRC::Client::Plugin;
    unit Plugin::Foo is IRC::Client::Plugin;

    # Listen to PRIVMSG IRC events:
    method irc-privmsg ($msg) {
        return IRC_NEXT unless $msg.channel eq '#perl6';
        $msg.reply: 'Nice to meet you!';
    }

    method irc-custom-my-event ($some, $random, :$args) {
        return IRC_NEXT unless $random > 5;
        $.irc.send: where => '#perl6', what => 'Custom event triggered!';
    }
```

An event listener receives the event message in the form of an object.
The object must provide all the relevant information about the source
and content of the message.

The message object's attributes must be mutable, and where appropriate,
it must provide a means to send the message back to the originator
of the message. For example, here's a potential implementation of
`PRIVMSG` handler that receives the message object:

```perl6
    method irc-privmsg ($msg) {
        return IRC_NEXT unless $msg.channel eq '#perl6';
        $msg.reply: 'Nice to meet you!';
    }
```

The message object should include a means to access the Client Object to
perform operations best suited for it and not the message object. Here is
a possible implementation to re-emit a `NOTICE` message sent to channel
`#perl6` as a `PRIVMSG` message.

```perl6
    method irc-notice ($msg) {
        $.irc.emit: 'PRIVMSG', $msg
            if $msg.channel eq '#perl6';

        IRC_NEXT;
    }
```

A plugin can send messages and emit events at will:

```perl6
    method irc-connected {
        Supply.interval(60).tap: {
            $.irc.send: where => '#perl6', what  => 'One minute passed!!';
        };
        Promise.in(60*60).then: {
            $.irc.send:
                where => 'Zoffix',
                what => 'I lived for one hour already!",
                :notice;

            $.irc.emit: 'CUSTOM-MY-EVENT', 'One hour passed!';
        }
    }
```

## Supported Events

### Channel Operations

[RFC 1459, 4.2](https://tools.ietf.org/html/rfc1459#section-4.2)

#### `irc-join`

```perl6
    # :zoffix!zoffix@127.0.0.1 JOIN :#perl6

    method irc-join ($msg) {
        printf "%s joined channel %s\n", .nick, .channel given $msg;
    }
```

[RFC 1459, 4.2.1](https://tools.ietf.org/html/rfc1459#section-4.2.1).
Emitted when user joins a channel.

#### `irc-part`

```perl6
    # :zoffix!zoffix@127.0.0.1 PART #perl6 :Leaving

    method irc-part ($msg) {
        printf "%s left channel %s (%s)\n", .nick, .channel, .reason given $msg;
    }
```

[RFC 1459, 4.2.2](https://tools.ietf.org/html/rfc1459#section-4.2.2).
Emitted when user leaves a channel.

#### `irc-mode`

```perl6
    # :zoffix!zoffix@127.0.0.1 MODE #perl6 +o zoffix2
    # :zoffix!zoffix@127.0.0.1 MODE #perl6 +bbb Foo!*@* Bar!*@* Ber!*@*
    # :zoffix2!f@127.0.0.1 MODE zoffix2 +w

    method irc-mode ($msg) {
        if $msg?.channel {
            # channel mode change
            printf "%s set mode(s) %s in channel %s\n",
                .nick, .modes, .channel given $msg;
        }
        else {
            # user mode change
            printf "Nick %s set mode(s) %s on user %s\n",
                .nick, .modes, .who given $msg;
        }
    }
```

[RFC 1459, 4.2.3](https://tools.ietf.org/html/rfc1459#section-4.2.3).
Emitted when IRC `MODE` command is received. As the command is dual-purpose,
the message object will have either `.channel` method available
(for channel mode changes) or `.who` method (for user mode changes). See
also `irc-mode-channel` and `irc-mode-user` convenience events.

For channel modes, the `.modes` method returns a list of `Pair` where key
is the mode set and the value is the argument for that mode (i.e. "limit",
"user", or "banmask") or an empty string if the mode takes no arguments.

For user modes, the `.modes` method returns a list of `Str` of the modes
set.

#### `irc-topic`

```perl6
    # :zoffix!zoffix@127.0.0.1 TOPIC #perl6 :meow

    method irc-topic ($msg) {
        printf "%s set topic of channel %s to %s\n",
            .nick, .channel, .topic given $msg;
    }
```

[RFC 1459, 4.2.4](https://tools.ietf.org/html/rfc1459#section-4.2.4).
Emitted when a user changes topic of a channel.

#### `irc-invite`

```perl6
    # :zoffix!zoffix@127.0.0.1 INVITE zoffix2 :#perl6

    method irc-invite ($msg) {
        printf "%s invited us to channel %s\n",
            .nick, .channel given $msg;
    }
```

[RFC 1459, 4.2.7](https://tools.ietf.org/html/rfc1459#section-4.2.7).
Emitted when a user invites us to a channel.

### Convenience Events

These sets of events do not have a corresponding IRC command defined by the
protocol and instead are offered to make listening for a specific kind
of events easier.

#### `irc-mode-channel`

```perl6
    # :zoffix!zoffix@127.0.0.1 MODE #perl6 +o zoffix2
    # :zoffix!zoffix@127.0.0.1 MODE #perl6 +bbb Foo!*@* Bar!*@* Ber!*@*

    method irc-mode-channel ($msg) {
        printf "Nick %s with usermask %s set mode(s) %s in channel %s\n",
            .nick, .usermask, .modes, .channel given $msg;
    }
```

Emitted when IRC `MODE` command is received and it's being operated on a
channel, see `irc-mode` event for details.

#### `irc-mode-user`

```perl6
    # :zoffix2!f@127.0.0.1 MODE zoffix2 +w

    method irc-mode-user ($msg) {
        printf "Nick %s with usermask %s set mode(s) %s on user %s\n",
            .nick, .usermask, .modes, .who given $msg;
    }
```

Emitted when IRC `MODE` command is received and it's being operated on a
user, see `irc-mode` event for details.
