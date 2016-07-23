# TABLE OF CONTENTS
- [PURPOSE](#purpose)
- [GOALS](#goals)
    - [Ease of Use](#ease-of-use)
    - [Client-Generated Events](#client-generated-events)
    - [Possibility of Non-Blocking Code](#possibility-of-non-blocking-code)
- [DESIGN](#design)
- [Multi-Server Interface](#multi-server-interface)
- [Client Object](#client-object)
    - [`$.irc` (access from inside a plugin)](#irc-access-from-inside-a-plugin)
    - [`.new`](#new)
    - [`.run`](#run)
    - [`.quit`](#quit)
    - [`.part`](#part)
    - [`.join`](#join)
    - [`.send`](#send)
    - [`.nick`](#nick)
    - [`.emit`](#emit)
    - [`.emit-custom`](#emit-custom)
    - [`.channel`](#channel)
        - [`.has`](#has)
        - [`.topic`](#topic)
        - [`.modes`](#modes)
        - [`.bans`](#bans)
        - [`.names`](#names)
- [Message Delivery](#message-delivery)
- [Response Constants](#response-constants)
    - [`IRC_NEXT`](#irc_next)
    - [`IRC_DONE`](#irc_done)
- [Message Object Interface](#message-object-interface)
    - [`.nick`](#nick-1)
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
    - [`irc-notice-me`](#irc-notice-me)
    - [`irc-started`](#irc-started)
    - [`irc-connected`](#irc-connected)
    - [`irc-mode-channel`](#irc-mode-channel)
    - [`irc-mode-user`](#irc-mode-user)
    - [`irc-all`](#irc-all)
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
- [Custom Events](#custom-events)

# PURPOSE

The purpose of IRC::Client is to serve as a fully-functional IRC
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

# Multi-Server Interface

The interface described in the rest of this document assumes a connection
to a single server. Should the client be connected to multiple-servers at
the time, issuing commands described will apply to *every* connected server.
A server must be specified to issue a command to a single server.
**Plugin authors must keep this fact in mind, when writing plugins, as
forgetting to handle multiple servers can result in unwanted behaviour.**

The same reasoning applies to the `.new` method: attributes, such as
nicknames, usernames, etc. given without associating them with a server will
apply to ALL connected servers. Configuration for individual servers is
given via `:servers` named parameter as a list of `Pairs`. The key
is the nickname of server and must be a valid method name. It's recommended
to choose something that won't end up an actual method on the Client Object.
It's guaranteed methods starting with `s-` will always be safe to use. The
value is a list of pairs that can be accepted by the Client Object as named
parameters (except for `:servers`) that specify the configuration for that
specific server, overriding any of the non-server-specific parameters already
set.

A possible `.new` setup may look something like this:

```perl6
    my $irc = IRC::Client.new:
        :nick<ZofBot ZofBot_ ZofBot__> # nicks to try to use on ALL servers,
        :servers(
            s-leliana => (
                :server<irc.freenode.net>,
                :channels<#perl #perl6 #perl7>
            ),
            s-morrigan => (
                :server<irc.perl.org>,
                :channels<#perl #perl-help>
            ),
            s-alistair => (
                :nick<Party Party_ Party__> # nick override
                :server<irc.perl6.pary>,
                :channels<#perler>
            ),
        ),
```

Use of multiple servers is facilitated via server nicknames and using
them as a method call to obtain the correct Client Object. For example:

```perl6
    $.irc.quit; # quits all servers
    $.irc.s-leliana.quit; # quits only the s-leliana server

    # send a message to #perl6 channel on s-morrigan server
    $.irc.s-morrigan.send: where => '#perl6', text => 'hello';
```

The Message Object will also contain a `.server` method value of which
is the nickname of the server from which the message arrived. In general,
the most common way to generate messages will be using `.reply` on the Message
Object, making the multi-server paradigm completely transparent.

# Client Object

Client Object represents a connected IRC client and is aware of and can
manipulate its state, such as disconnecting, joining or parting a channel,
or sending messages.

A Client Object must support the ability to connect to multiple servers.
The client object provides these methods:

## `$.irc` (access from inside a plugin)

```perl6
    use IRC::Client::Plugin;
    unit Plugin::Foo is IRC::Client::Plugin;

    method irc-privmsg-me ($msg) {
        $.irc.send:
            where => '#perl6',
            text => "$msg.nick() just sent me a secret! It's $msg.text()";
    }
```

A plugin inherits from `IRC::Client::Plugin`, which provides `$.irc`
attribute containing the Client Object, allowing the plugin to utilize all
of the methods it provides.

## `.new`

```perl6
    my $irc = IRC::Client.new:
        ...
        :plugins(
            IRC::Client::Plugin::Factoid.new,
            My::Plugin.new,
            class :: is IRC::Client::Plugin {
                method irc-privmsg-me ($msg) { $msg.repond: 'Go away!'; }
            },
        );
```

*Not to be used inside plugins.*
Creates a new `IRC::Client` object. Along with the usual arguments like
nick, username, server address, etc, takes `:plugins` argument that
lists the plugins to include. All messages will be propagated through plugins
in the order they are defined here.

## `.run`

```perl6
    $irc.run;
```

*Not to be used inside plugins.*
Starts the client, connecting to the server and maintaining that connection
and not returning until an explicit  `.quit` is issued. If the connection
breaks, the client will attempt to reconnect.

## `.quit`

```perl6
    $.irc.quit;

    $.irc.quit: 'Reason';
```

Disconnects from the server. Takes an option string to be given to the
server as the reson for quitting.

## `.part`

```per6
    $.irc.part: '#perl6';

    $.irc.part: '#perl6', 'Leaving';
```

Exits a channel. Takes two positional strings: the channel to part
and an optional parting message. Causes the client object to discard any state
kept for this channel.

## `.join`

```perl6
    $.irc.join '#perl6', '#perl7';
```

Attempts to joins channels given as positional arguments.

## `.send`

```perl6
    $.irc.send: where => '#perl6', text => 'Hello, Perl 6!';

    $.irc.send: where => 'Zoffix', text => 'Hi, Zoffie!';

    $.irc.send: where => 'Zoffix', text => 'Notice me, senpai!', :notice;
```

Sends a message specified by `text` argument
either to a user or a channel specified by `:where` argument. If `Bool`
argument `:notice` is set to true, will send a *notice* instead of regular
message.

Note that in IRC bots that respond to commands from other users a more
typical way to reply to those commands would be by calling
`.reply` method on the Message Object, rather than using `.send` method.


## `.nick`

```perl6
    $.irc.nick: 'ZofBot', 'ZofBot_', 'ZofBot__';
```

Attempts to change the nick of the client. Takes one or more positional
arguments that are a list of nicks to try.

## `.emit`

```perl6
    $.irc.emit: $msg;

    $.irc.emit: IRC::Client::Message::Privmsg.new:
        nick => 'Zoffix',
        text => 'Hello',
        ...;
    ...
    method irc-privmsg ($msg) {
        say "$msg.nick() said $msg.text()... or did they?";
    }
```

Takes an object of any of `IRC::Client::Message::*` subclass and emits it
as if it were a new event. That is, it will propagate through the plugin chain
starting at the first plugin, and not the one emiting the event, and the
plugins can't tell whether the message is self-generated or something that
came from the server.

## `.emit-custom`

```perl6
    $.irc.emit-custom: 'my-event', 'just', 'some', :args;
```

Same idea as `.emit`, except a custom event is emitted. The first positional
argument specifies the name of the event to emit. Any other arguments
given here will be passed as is to listener methods.

## `.channel`

```perl6
    method irc-addressed ($msg) {
        if $msg.text ~~ /'kick' \s+ $<nick>=\S+/ {
            $msg.reply: "I don't see $<nick> up in here"
                unless $.irc.channel($msg.channel).?has: ~$<nick>;
        }

        if $msg.text ~~ /'topic' \s+ $<channel>=\S+/ {
            return $msg.reply: $_
                    ?? "Channel $<channel> does not exist"
                    !! "Topic in $<channel> is $_.topic()"
                given $.irc.channel: ~$<channel>;
        }
    }
```

Returns an `IRC::Client::Channel` object for the channel given as positional
argument, or `False` if no such channel seems to exist. Unless our client is
currently *on* that channel, that existence is
determined with `LIST` IRC command, so there will be some false negatives,
such as when attempting to get an object for a channel with secret mode set.

The Client Object tracks state for any of the joined channels, so some
information obtainable via the Channel Object will be cached
and retrieved from that state, whenever possible. Otherwise, a request
to the server will be generated. Return values will be empty (empty lists
or empty strings) when requests fail. The channel object provides the
following methods.

### `.has`

```perl6
    $.irc.channel('#perl6').has: 'Zoffix';
```

Returns `True` or `False` indicating whether a user with the given nick is
present on the channel.

### `.topic`

```perl6
    say "Topic of the channel is " ~ $.irc.channel('#perl6').topic;
```

Returns the `TOPIC` of the channel.

### `.modes`

```perl6
    say $.irc.channel('#perl6').modes;
    # ('s', 'n', 't')
```

Returns a list of single-letter codes for currently active channel modes
on the channel. Note, this does not include any bans.

### `.bans`

```perl6
    say $.irc.channel('#perl6').bans;
    # ('*!spammer@*', 'warezbot!*@*')
```

Returns a list of currently active ban masks on the channel.

### `.names`

```perl6
    say $.irc.channel('#perl6').names;
    # ('@Zoffix', '+zoffixs-helper', 'not-zoffix')
```

Returns a list of nicks present on the channel, each potentially prefixed
with a [channel membership prefix](https://www.alien.net.au/irc/chanmembers.html)

# Message Delivery

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

    # Listen to custom client-generated events:
    method irc-custom-my-event ($some, $random, :$args) {
        return IRC_NEXT unless $random > 5;
        $.irc.send: where => '#perl6', text => 'Custom event triggered!';
    }
```

An event listener receives the event message in the form of an object.
The object must provide all the relevant information about the source
and content of the message.

The message object, where appropriate, must provide a means to send a reply
back to the originator of the message. For example, here's a potential
implementation of `PRIVMSG` handler that receives the message object:

```perl6
    method irc-privmsg-channel ($msg) {
        return IRC_NEXT unless $msg.channel eq '#perl6';
        $msg.reply: 'Nice to meet you!';
    }
```

A plugin can send messages and emit events at will:

```perl6
    method irc-connected {
        Supply.interval(60).tap: {
            $.irc.send: where => '#perl6', text  => 'One minute passed!!';
        };
        Promise.in(60*60).then: {
            $.irc.send:
                where => 'Zoffix',
                text => 'I lived for one hour already!',
                :notice;

            $.irc.emit-custom: 'MY-EVENT', 'One hour passed!';
        }
    }
```

# Response Constants

Multiple plugins can listen to the same event. The event message will be
handed to each of the plugins in the sequence they are defined when the
Client Object is initialized. Each handler can use predefined response
constants to signal whether the handling of this particular event message
should stop or continue onto the next plugin. These response constants
are `IRC_NEXT` and `IRC_DONE` and are exported by `IRC::Client::Plugin`.

## `IRC_NEXT`

```perl6
    method irc-privmsg-channel ($msg) {
        return IRC_NEXT unless $msg.channel eq '#perl6';
        ....
    }
```

Signals that the message should continue to be passed on to any further
plugins that subscribed to handle it.

## `IRC_DONE`

```perl6
    method irc-privmsg-channel ($msg) {
        return IRC_DONE if $msg.channel eq '#perl6';
    }

    # or just...

    method irc-privmsg-channel ($msg) {}
```

Signals that the message has been handled and should NOT be passed on
to any further plugins. **Note:** you don't have to explicitly return this
value; anything other than returning `IRC_NEXT` is the same as returning
`IRC_DONE`.


# Message Object Interface

The message object received by all non-custom events is an event-specific
subclass of `IRC::Client::Message`. The subclass is named
`IRC::Client::Message::$NAME`, where `$NAME` is:

* *Named* and *Convenience* events use their names without `irc-` part, with any `-`
changed to `::` and with each word written in `Title Case`. e.g.
message object for `irc-privmsg-me` is `IRC::Client::Message::Privmsg::Me`
* *Numeric* events always receive `IRC::Client::Message::Numeric` message
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
        if $msg.text ~~ /'I love you'/;
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
            .nick, .text, .how given $msg;
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
            .nick, .text, .channel given $msg;
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
            .nick, .channel, .text given $msg;
    }
```

Emitted when a user mentions us in a channel. Specifically, this means
their message contains our nickname separated by a word boundary on each side.

## `irc-privmsg-channel`

```perl6
    # :zoffix!zoffix@127.0.0.1 PRIVMSG #perl6 :hello

    method irc-privmsg-channel ($msg) {
        printf "%s said `%s` to channel %s\n",
            .nick, .text, .channel given $msg;
    }
```

Emitted when a user sends a message to a channel.

## `irc-privmsg-me`

```perl6
    # :zoffix!zoffix@127.0.0.1 PRIVMSG zoffix2 :hey bruh

    method irc-privmsg-me ($msg) {
        printf "%s messaged us: %s\n", .nick, .text given $msg;
    }
```

Emitted when a user sends us a private message.

## `irc-notice-channel`

```perl6
    # :zoffix!zoffix@127.0.0.1 NOTICE #perl6 :Notice me!

    method irc-notice-channel ($msg) {
        printf "%s sent a notice `%s` to channel %s\n",
            .nick, .text, .channel given $msg;
    }
```

Emitted when a user sends a notice to a channel.

## `irc-notice-me`

```perl6
    # :zoffix!zoffix@127.0.0.1 NOTICE zoffix2 :did you notice me?

    method irc-notice-me ($msg) {
        printf "%s sent us a notice: %s\n", .nick, .text given $msg;
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
even if the client reconnects to the server numerous times. Note that
unlike most events, this event does *not* receive a Message Object.
**IMPORTANT:** when this event fires, there's no guarantee we even started a
connection to the server, let alone connected successfully.

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
Note that unlike most events, this event does *not* receive a Message Object.

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

## `irc-all`

```perl6
    method irc-all ($msg) {
        say "Received an event: $msg.perl()";
        return IRC_NEXT;
    }
```

Emitted for all events and is mostly useful for debugging. The type of the
message object received will depend on the type of the event that generated
the message. This event will be triggered *AFTER* all other event handlers
in the current plugin are processed.

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
        if $msg.?channel {
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

The received message object will be one of the subclasses of
`IRC::Client::Message::Mode` object: `IRC::Client::Message::Mode::Channel`
or `IRC::Client::Message::Mode::User`.

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
        if $msg.?channel {
            # message sent to a channel
            printf "%s said `%s` to channel %s\n",
                .nick, .text, .channel given $msg;
        }
        else {
            # private message
            printf "%s messaged us: %s\n", .nick, .text given $msg;
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
        if $msg.?channel {
            # notice sent to a channel
            printf "%s sent a notice `%s` to channel %s\n",
                .nick, .text, .channel given $msg;
        }
        else {
            # private notice
            printf "%s sent us a notice: %s\n", .nick, .text given $msg;
        }
    }
```

[RFC 2812, 3.3.2](https://tools.ietf.org/html/rfc2812#section-3.3.2).
Emitted when a user sends a notice either to a channel
or a private notice to us. See *Convenience Events* section for a number
of more convenient ways to listen to notices and messages.

# Custom Events

There is support for custom events. A custom event is emitted by calling
`.emit-custom` method on the Client Object and is subscribed to via
`irc-custom-*` methods:

```perl6
    $.irc.emit-custom: 'my-event', 'just', 'some', :args;
    ...
    method irc-custom-my-event ($just, $some, :$args) { }
```

No Message Object is involved in custom events.
