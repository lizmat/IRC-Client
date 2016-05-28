# TABLE OF CONTENTS
- [TABLE OF CONTENTS](#table-of-contents)
- [PURPOSE](#purpose)
- [GOALS](#goals)
    - [Ease of Use](#ease-of-use)
    - [Client-Generated Events](#client-generated-events)
    - [Possibility of Non-Blocking Code](#possibility-of-non-blocking-code)
- [DESIGN](#design)
- [Core](#core)
    - [Client Object](#client-object)
    - [Message Delivery](#message-delivery)
- [Message Object Interface](#message-object-interface)
    - [`.nick`](#nick)
    - [`.username`](#username)
    - [`.host`](#host)
    - [`.usermask`](#usermask)
    - [`.reply`](#reply)
- [Convenience Events](#convenience-events)
    - [`irc-to-me`](#irc-to-me)
    - [`irc-addressed`](#irc-addressed)
    - [`irc-mentioned`](#irc-mentioned)
    - [`irc-privmsg-channel`](#irc-privmsg-channel)
    - [`irc-privmsg-me`](#irc-privmsg-me)
    - [`irc-notice-channel`](#irc-notice-channel)
    - [`irc-privmsg-me`](#irc-privmsg-me-1)
    - [`irc-started`](#irc-started)
    - [`irc-connected`](#irc-connected)
    - [`irc-mode-channel`](#irc-mode-channel)
    - [`irc-mode-user`](#irc-mode-user)
- [Numeric Events](#numeric-events)
- [Named Events](#named-events)
    - [`irc-nick`](#irc-nick)
    - [`irc-quit`](#irc-quit)
    - [`irc-join`](#irc-join)
    - [`irc-part`](#irc-part)
    - [`irc-mode`](#irc-mode)
    - [`irc-topic`](#irc-topic)
    - [`irc-invite`](#irc-invite)
    - [`irc-kick`](#irc-kick)
    - [`irc-privmsg`](#irc-privmsg)
    - [`irc-notice`](#irc-notice)

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

# Core

## Client Object

Client Object represents a connected IRC client and is aware of and can
manipulate its state, such as disconnecting, joining or parting a channel,
or sending messages.

A program may have multiple Client Objects, but each of them can be connected
only to one IRC server.

A relevant Client Object must be easily accessible to the user of the
implementation. This includes user's plugins responsible for handling
events.

## Message Delivery

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

# Message Object Interface

The message object received by all non-custom events is an event-specific
subclass of `IRC::Client::Message`. The subclass is named
`IRC::Client::Message::$NAME`, where `$NAME` is:

* Named and Convenience events use their names without `irc-` part, with any `-`
changed to `::` and with each word written in `Title Case`. e.g.
message object for `irc-privmsg-me` is `IRC::Client::Message::Privmsg::Me`
* Numeric events always receive `IRC::Client::Message::Numeric` message
object, regardless of the actual number of the event.

Along with event-specific methods
described under each event, the `IRC::Client::Message` offers the following
methods:

## `.nick`

```perl6
    say $msg.nick ~ " says hello";
```

Contains the nickname of the sender of the message.

## `.username`

```perl6
    say $msg.nick ~ " has username " ~ $msg.username;
```

Contains the username of the sender of the message.

## `.host`

```perl6
    say $msg.nick ~ " is connected from " ~ $msg.host;
```

Hostname of sender of the message.

## `.usermask`

```perl6
    say $msg.usermask;
```

Nick, username, and host combined into a full usermask, e.g.
`Zoffix!zoffix@zoffix.com`

## `.reply`

```perl6
    $msg.reply: 'I love you too'
        if $msg.what ~~ /'I love you'/;
```

Replies back to a message. For example, if we received the message as a
private message to us, the reply will be a private message back to the
user. Same for notices. For in-channel messages, `irc-addressed`
and `irc-to-me` will address the sender in return, while all other in-channel
events will not.

**NOTE:** this method is only available for these events:

* `irc-privmsg`
* `irc-notice`
* `irc-to-me`
* `irc-addressed`
* `irc-mentioned`
* `irc-privmsg-channel`
* `irc-privmsg-me`
* `irc-notice-channel`
* `irc-privmsg-me`

# Convenience Events

These sets of events do not have a corresponding IRC command defined by the
protocol and instead are offered to make listening for a specific kind
of events easier.

## `irc-to-me`

```perl6
    # :zoffix!zoffix@127.0.0.1 PRIVMSG zoffix2 :hello
    # :zoffix!zoffix@127.0.0.1 NOTICE zoffix2 :hello
    # :zoffix!zoffix@127.0.0.1 PRIVMSG #perl6 :zoffix2, hello

    method irc-to-me ($msg) {
        printf "%s told us `%s` using %s\n",
            .nick, .what, .how given $msg;
    }
```

Emitted when a user sends us a message as a private message, notice, or
addresses us in a channel. The `.respond` method of the Message
Object is the most convenient way to respond back to the sender of the message.

The `.how` method returns a `Pair` where the key is the message type used
(`PRIVMSG` or `NOTICE`) and the value is the addressee of that message
(a channel or us).

## `irc-addressed`

```perl6
    # :zoffix!zoffix@127.0.0.1 PRIVMSG #perl6 :zoffix2, hello

    method irc-addressed ($msg) {
        printf "%s told us `%s` in channel %s\n",
            .nick, .what, .channel given $msg;
    }
```

Emitted when a user addresses us in a channel. Specifically, this means
their message starts with our nickname, followed by optional comma or colon,
followed by whitespace. That prefix will be stripped from the message.

## `irc-mentioned`

```perl6
    # :zoffix!zoffix@127.0.0.1 PRIVMSG #perl6 :Is zoffix2 a robot?

    method irc-mentioned ($msg) {
        printf "%s mentioned us in channel %s when they said %s\n",
            .nick, .channel, .what given $msg;
    }
```

Emitted when a user mentions us in a channel. Specifically, this means
their message contains our nickname separated by a word boundary on each side.

## `irc-privmsg-channel`

```perl6
    # :zoffix!zoffix@127.0.0.1 PRIVMSG #perl6 :hello

    method irc-privmsg-channel ($msg) {
        printf "%s said `%s` to channel %s\n",
            .nick, .what, .channel given $msg;
    }
```

Emitted when a user sends a message to a channel.

## `irc-privmsg-me`

```perl6
    # :zoffix!zoffix@127.0.0.1 PRIVMSG zoffix2 :hey bruh

    method irc-privmsg-me ($msg) {
        printf "%s messaged us: %s\n", .nick, .what given $msg;
    }
```

Emitted when a user sends us a private message.

## `irc-notice-channel`

```perl6
    # :zoffix!zoffix@127.0.0.1 NOTICE #perl6 :Notice me!

    method irc-notice-channel ($msg) {
        printf "%s sent a notice `%s` to channel %s\n",
            .nick, .what, .channel given $msg;
    }
```

Emitted when a user sends a notice to a channel.

## `irc-privmsg-me`

```perl6
    # :zoffix!zoffix@127.0.0.1 NOTICE zoffix2 :did you notice me?

    method irc-notice-me ($msg) {
        printf "%s sent us a notice: %s\n", .nick, .what given $msg;
    }
```

Emitted when a user sends us a private notice.

## `irc-started`

```perl6
    method irc-started {
        $.do-some-sort-of-init-setup;
    }
```

Emitted when the IRC client is started. Useful for doing setup work, like
initializing database connections, etc. Note: this event will fire only once,
even if the client reconnects to the server numerous times. *IMPORTANT:*
when this event fires, there's no guarantee we event started a connection to
the server, let alone connected successfully.

## `irc-connected`

```perl6
    method irc-connected {
        $.do-some-sort-of-per-connection-setup;
    }
```

Similar to `irc-started`, except will be emitted every time a
*successful* connection to the server is made and we joined all
of the requested channels. That is, we'll wait to either receive the
full user list or error message for each of the channels we're joining.

## `irc-mode-channel`

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

## `irc-mode-user`

```perl6
    # :zoffix2!f@127.0.0.1 MODE zoffix2 +w

    method irc-mode-user ($msg) {
        printf "Nick %s with usermask %s set mode(s) %s on user %s\n",
            .nick, .usermask, .modes, .who given $msg;
    }
```

Emitted when IRC `MODE` command is received and it's being operated on a
user, see `irc-mode` event for details.

# Numeric Events

Numeric IRC events can be subscribed to by defining a method with name
`irc-` followed by the numeric code of the event (e.g. `irc-001`). The
arguments of the event can be accessed via `.args` method that returns a
list of strings:

```perl6
    method irc-004 ($msg) {
        say "Here are the arguments of the RPL_MYINFO event:";
        .say for $msg.args;
    }
```

See [this reference](https://www.alien.net.au/irc/irc2numerics.html) for
a detailed list of numerics and their arguments available in the wild. Note:
the client will emit an event for any received numeric with a 3-digit
code, regardless of whether it is listed in that reference.

# Named Events

## `irc-nick`

```perl6
    # :zoffix!zoffix@127.0.0.1 NICK not-zoffix

    method irc-nick ($msg) {
        printf "%s changed nickname to %s\n", .nick, .new-nick given $msg;
    }
```

[RFC 2812, 3.1.2](https://tools.ietf.org/html/rfc2812#section-3.1.2).
Emitted when a user changes their nickname.

## `irc-quit`

```perl6
    # :zoffix!zoffix@127.0.0.1 QUIT :Quit: Leaving

    method irc-quit ($msg) {
        printf "%s has quit (%s)\n", .nick, .reason given $msg;
    }
```

[RFC 2812, 3.1.7](https://tools.ietf.org/html/rfc2812#section-3.1.7).
Emitted when a user quits the server.

## `irc-join`

```perl6
    # :zoffix!zoffix@127.0.0.1 JOIN :#perl6

    method irc-join ($msg) {
        printf "%s joined channel %s\n", .nick, .channel given $msg;
    }
```

[RFC 2812, 3.2.1](https://tools.ietf.org/html/rfc2812#section-3.2.1).
Emitted when a user joins a channel.

## `irc-part`

```perl6
    # :zoffix!zoffix@127.0.0.1 PART #perl6 :Leaving

    method irc-part ($msg) {
        printf "%s left channel %s (%s)\n", .nick, .channel, .reason given $msg;
    }
```

[RFC 2812, 3.2.2](https://tools.ietf.org/html/rfc2812#section-3.2.2).
Emitted when a user leaves a channel.

## `irc-mode`

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
            printf "%s set mode(s) %s on user %s\n",
                .nick, .modes, .who given $msg;
        }
    }
```

[RFC 2812, 3.1.5](https://tools.ietf.org/html/rfc2812#section-3.1.5)/[RFC 2812, 3.2.3](https://tools.ietf.org/html/rfc2812#section-3.2.3).
Emitted when IRC `MODE` command is received. As the command is dual-purpose,
the message object will have either `.channel` method available
(for channel mode changes) or `.who` method (for user mode changes). See
also `irc-mode-channel` and `irc-mode-user` convenience events.

For channel modes, the `.modes` method returns a list of `Pair` where key
is the mode set and the value is the argument for that mode (i.e. "limit",
"user", or "banmask") or an empty string if the mode takes no arguments.

For user modes, the `.modes` method returns a list of `Str` of the modes
set.

## `irc-topic`

```perl6
    # :zoffix!zoffix@127.0.0.1 TOPIC #perl6 :meow

    method irc-topic ($msg) {
        printf "%s set topic of channel %s to %s\n",
            .nick, .channel, .topic given $msg;
    }
```

[RFC 2812, 3.2.4](https://tools.ietf.org/html/rfc2812#section-3.2.4).
Emitted when a user changes the topic of a channel.

## `irc-invite`

```perl6
    # :zoffix!zoffix@127.0.0.1 INVITE zoffix2 :#perl6

    method irc-invite ($msg) {
        printf "%s invited us to channel %s\n", .nick, .channel given $msg;
    }
```

[RFC 2812, 3.2.7](https://tools.ietf.org/html/rfc2812#section-3.2.7).
Emitted when a user invites us to a channel.

## `irc-kick`

```perl6
    # :zoffix!zoffix@127.0.0.1 KICK #perl6 zoffix2 :go away

    method irc-kick ($msg) {
        printf "%s kicked %s out of %s (%s)\n",
            .nick, .who, .channel, .reason given $msg;
    }
```

[RFC 2812, 3.2.8](https://tools.ietf.org/html/rfc2812#section-3.2.8).
Emitted when someone kicks a user out of a channel.

## `irc-privmsg`

```perl6
    # :zoffix!zoffix@127.0.0.1 PRIVMSG #perl6 :hello
    # :zoffix!zoffix@127.0.0.1 PRIVMSG zoffix2 :hey bruh

    method irc-privmsg ($msg) {
        if $msg?.channel {
            # message sent to a channel
            printf "%s said `%s` to channel %s\n",
                .nick, .what, .channel given $msg;
        }
        else {
            # private message
            printf "%s messaged us: %s\n", .nick, .what given $msg;
        }
    }
```

[RFC 2812, 3.3.1](https://tools.ietf.org/html/rfc2812#section-3.3.1).
Emitted when a user sends a message either to a channel
or a private message to us. See *Convenience Events* section for a number
of more convenient ways to listen to messages.

## `irc-notice`

```perl6
    # :zoffix!zoffix@127.0.0.1 NOTICE #perl6 :Notice me!
    # :zoffix!zoffix@127.0.0.1 NOTICE zoffix2 :did you notice me?

    method irc-notice ($msg) {
        if $msg?.channel {
            # notice sent to a channel
            printf "%s sent a notice `%s` to channel %s\n",
                .nick, .what, .channel given $msg;
        }
        else {
            # private notice
            printf "%s sent us a notice: %s\n", .nick, .what given $msg;
        }
    }
```

[RFC 2812, 3.3.2](https://tools.ietf.org/html/rfc2812#section-3.3.2).
Emitted when a user sends a notice either to a channel
or a private notice to us. See *Convenience Events* section for a number
of more convenient ways to listen to notices and messages.
