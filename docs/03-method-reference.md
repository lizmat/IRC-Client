[[back to doc map]](README.md)

# Method Reference

This document describes events available on various objects in use when working
with `IRC::Client`.

## Table of Contents

- [Message Objects (`IRC::Client::Message` and subclasses)](#message-objects-ircclientmessage-and-subclasses)
    - [Message Object Hierarchy](#message-object-hierarchy)
    - [Methods and Attributes](#methods-and-attributes)
        - [`IRC::Client::Message`](#ircclientmessage)
            - [`.irc`](#irc)
            - [`.nick`](#nick)
            - [`.username`](#username)
            - [`.host`](#host)
            - [`.usermask`](#usermask)
            - [`.command`](#command)
            - [`.server`](#server)
            - [`.args`](#args)
            - [`.Str`](#str)
        - [`IRC::Client::Message::Join`](#ircclientmessagejoin)
            - [`.channel`](#channel)
        - [`IRC::Client::Message::Nick`](#ircclientmessagenick)
            - [`.new-nick`](#new-nick)
        - [`IRC::Client::Message::Numeric`](#ircclientmessagenumeric)
        - [`IRC::Client::Message::Part`](#ircclientmessagepart)
            - [`.channel`](#channel-1)
        - [`IRC::Client::Message::Ping`](#ircclientmessageping)
            - [`.reply`](#reply)
        - [`IRC::Client::Message::Quit`](#ircclientmessagequit)
        - [`IRC::Client::Message::Unknown`](#ircclientmessageunknown)
            - [`.Str`](#str-1)
        - [`IRC::Client::Message::Mode`](#ircclientmessagemode)
            - [`.modes`](#modes)
        - [`IRC::Client::Message::Mode::Channel`](#ircclientmessagemodechannel)
            - [`.channel`](#channel-2)
        - [`IRC::Client::Message::Mode::Me`](#ircclientmessagemodeme)
        - [`IRC::Client::Message::Notice`](#ircclientmessagenotice)
            - [`.text`](#text)
            - [`.replied`](#replied)
            - [`.Str`](#str-2)
        - [`IRC::Client::Message::Notice::Channel`](#ircclientmessagenoticechannel)
            - [`.channel`](#channel-3)
            - [`.reply`](#reply-1)
        - [`IRC::Client::Message::Notice::Me`](#ircclientmessagenoticeme)
            - [`.reply`](#reply-2)
        - [`IRC::Client::Message::Privmsg`](#ircclientmessageprivmsg)
            - [`.text`](#text-1)
            - [`.replied`](#replied-1)
            - [`.Str`](#str-3)
        - [`IRC::Client::Message::Privmsg::Channel`](#ircclientmessageprivmsgchannel)
            - [`.channel`](#channel-4)
            - [`.reply`](#reply-3)
        - [`IRC::Client::Message::Privmsg::Me`](#ircclientmessageprivmsgme)
            - [`.reply`](#reply-4)
- [Server Object (`IRC::Client::Server`)](#server-object-ircclientserver)
    - [Labels](#labels)
    - [Methods and Attributes](#methods-and-attributes-1)
        - [`.label`](#label)
        - [`.channels`](#channels)
        - [`.nick`](#nick-1)
        - [`.alias`](#alias)
        - [`.host`](#host-1)
        - [`.port`](#port)
        - [`.password`](#password)
        - [`.username`](#username-1)
        - [`.userhost`](#userhost)
        - [`.userreal`](#userreal)
        - [`.Str`](#str-4)
        - [Writable Non-Writable Attributes](#writable-non-writable-attributes)
            - [`.current-nick`](#current-nick)
            - [`.is-connected`](#is-connected)
            - [`.has-quit`](#has-quit)
            - [`.has-quit`](#has-quit-1)
- [Client Object (`IRC::Client`)](#client-object-ircclient)
    - [Methods and Attributes](#methods-and-attributes-2)
        - [`.join`](#join)
        - [`.new`](#new)
            - [`:channels`](#channels-1)
            - [`:debug`](#debug)
            - [`:filters`](#filters)
            - [`:host`](#host-2)
            - [`:nick`](#nick-2)
            - [`:alias`](#alias-1)
            - [`:password`](#password-1)
            - [`:plugins`](#plugins)
            - [`:port`](#port-1)
            - [`:servers`](#servers)
            - [`:username`](#username-2)
            - [`:userhost`](#userhost-1)
            - [`:userreal`](#userreal-1)
        - [`.nick`](#nick-3)
        - [`.part`](#part)
        - [`.quit`](#quit)
        - [`.run`](#run)
        - [`.send`](#send)
- [Up Next](#up-next)

---

## Message Objects (`IRC::Client::Message` and subclasses)

All event handlers (except for special `irc-started`) receive one positional
argument that does `IRC::Client::Message` role and is refered to as
the Message Object throughout the documentation. The actual received
message object depends on the event the event handler is subscribed to.
See [event reference](02-event-reference.md) to learn which message objects
an event can receive.

### Message Object Hierarchy

All message objects reside in the `IRC::Client::Message` package and
follow the following hierarchy, with children having all the methods
and attributes of their parents.

```
IRC::Client::Message
│
├───IRC::Client::Message::Join
├───IRC::Client::Message::Nick
├───IRC::Client::Message::Numeric
├───IRC::Client::Message::Part
├───IRC::Client::Message::Ping
├───IRC::Client::Message::Quit
├───IRC::Client::Message::Unknown
│
├───IRC::Client::Message::Mode
│   ├───IRC::Client::Message::Mode::Channel
│   └───IRC::Client::Message::Mode::Me
│
├───IRC::Client::Message::Notice
│   ├───IRC::Client::Message::Notice::Channel
│   └───IRC::Client::Message::Notice::Me
│
└───IRC::Client::Message::Privmsg
    ├───IRC::Client::Message::Privmsg::Channel
    └───IRC::Client::Message::Privmsg::Me
```

### Methods and Attributes

Subclasses inherit all the methods and attributes of their parents (see
hierarchy chart above). Some event handlers can receive more than one
type of a message object. In many cases, the type can be differentiated
with a safe-method-call operator (`.?`):

```perl6
    method irc-privmsg ($e) {
        if $e.?channel {
            say '$e is a IRC::Client::Message::Privmsg::Channel';
        }
        else {
            say '$e is a IRC::Client::Message::Privmsg::Me';
        }
    }
```

---

#### `IRC::Client::Message`

Object is never sent to event handlers and merely provides commonality to
its subclasses.

##### `.irc`

Contains the `IRC::Client` object.

##### `.nick`

Contains the nick of the sender of the message.

##### `.username`

Contains the username of the sender of the message.

##### `.host`

Contains the host of the sender of the message.

##### `.usermask`

Contains the usermask of the sender of the message. That is
string constructed as `nick!username@host`

##### `.command`

The IRC command responsible for this event, such as `PRIVMSG` or `001`.

##### `.server`

The `IRC::Client::Server` object from which the event originates.

##### `.args`

A possibly-empty list of arguments, received for the IRC command that triggered
the event.

##### `.Str`

(affects stringification of message objects). Returns a string
constructed from `":$!usermask $!command $!args[]"`, but is overriden to
a different value by some message objects.

---

#### `IRC::Client::Message::Join`

##### `.channel`

Contains the channel name of the channel that was joined

---

#### `IRC::Client::Message::Nick`

##### `.new-nick`

Contains the new nick switched to (`.nick` attribute contains the old one).

---

#### `IRC::Client::Message::Numeric`

Does not offer any object-specific methods. Use the `.command` attribute
to find out the actual 3-digit IRC command that triggered the event.

---

#### `IRC::Client::Message::Part`

##### `.channel`

Contains the channel name of the channel that was parted. Use `.args`
attribute to get any potential parting messages.

---

#### `IRC::Client::Message::Ping`

**Included in the docs for completeness only.** Used internally. Not sent
to any event handlers and `irc-ping` is not a valid event.

##### `.reply`

Takes no arguments. Replies to the server with appropriate `PONG` IRC command.

---

#### `IRC::Client::Message::Quit`

Does not offer any object-specific methods. Use `.args`
attribute to get any potential quit messages.

---

#### `IRC::Client::Message::Unknown`

##### `.Str`

Overrides the default stringification string to
`"❚⚠❚ :$.usermask $.command $.args[]"`

---

#### `IRC::Client::Message::Mode`

Object is never sent to event handlers and merely provides commonality to
its subclasses.

##### `.modes`

Contains the modes set by the IRC command that triggered the event. When
modes are set on the channel, contains a list of `Pair`s where the key
is the sign of the mode (`+` or `-`) and the value if the mode letter itself.
When modes are set on the client, contains just a list of modes as strings,
without any signs.

---

#### `IRC::Client::Message::Mode::Channel`

##### `.channel`

Contains the channel on which the modes were set.

---

#### `IRC::Client::Message::Mode::Me`

Does not offer any object-specific methods.

---

#### `IRC::Client::Message::Notice`

Object is never sent to event handlers and merely provides commonality to
its subclasses.

##### `.text`

Writable attribute. Contains the text of the message.

##### `.replied`

Writable `Bool` attribute. Automatically gets set to `True` by the
`.reply` method. If set to `True`, indicates to the Client Object that
the event handler's value must not be used as a reply to the message.

##### `.Str`

Overrides stringification of the message object to be the value of the
`.text` attribute.

---

#### `IRC::Client::Message::Notice::Channel`

##### `.channel`

Contains the channel to which the message was sent.

##### `.reply`

```perl6
    $e.reply: "Hello, World!";
    $e.reply: "Hello, World!", :where<#perl6>;
    $e.reply: "Hello, World!", :where<Zoffix>;
```

Replies to the sender of the message using the `NOTICE` IRC command. The
optional `:where` argument specifies a channel or nick
where to send the message and defaults to the channel in which the message
originated.

---

#### `IRC::Client::Message::Notice::Me`

##### `.reply`

```perl6
    $e.reply: "Hello, World!";
    $e.reply: "Hello, World!", :where<Zoffix>;
    $e.reply: "Hello, World!", :where<#perl6>;
```

Replies to the sender of the message using the `NOTICE` IRC command. The
optional `:where` argument specifies a nick or channel
where to send the message and defaults to the nick from which the message
originated.

---

#### `IRC::Client::Message::Privmsg`

Object is never sent to event handlers and merely provides commonality to
its subclasses.

##### `.text`

Writable attribute. Contains the text of the message.

##### `.replied`

Writable `Bool` attribute. Automatically gets set to `True` by the
`.reply` method. If set to `True`, indicates to the Client Object that
the event handler's value must not be used as a reply to the message.

##### `.Str`

Overrides stringification of the message object to be the value of the
`.text` attribute.

---

#### `IRC::Client::Message::Privmsg::Channel`

##### `.channel`

Contains the channel to which the message was sent.

##### `.reply`

```perl6
    $e.reply: "Hello, World!";
    $e.reply: "Hello, World!", :where<#perl6>;
    $e.reply: "Hello, World!", :where<Zoffix>;
```

Replies to the sender of the message using the `PRIVMSG` IRC command. The
optional `:where` argument specifies a channel or nick
where to send the message and defaults to the channel in which the message
originated.

---

#### `IRC::Client::Message::Privmsg::Me`

##### `.reply`

```perl6
    $e.reply: "Hello, World!";
    $e.reply: "Hello, World!", :where<Zoffix>;
    $e.reply: "Hello, World!", :where<#perl6>;
```

Replies to the sender of the message using the `PRIVMSG` IRC command. The
optional `:where` argument specifies a nick or channel
where to send the message and defaults to the nick from which the message
originated.

---

## Server Object (`IRC::Client::Server`)

The Server Object represents one of the IRC servers the client is connected
to. It's returned by the `.server` attribute of the Message Object and
can be passed to various Client Object methods to indicate to which server
a command should be sent to.

Client Object's `%.servers` attribute contains all of the `IRC::Client::Server`
objects with their keys as labels and values as objects themselves.

### Labels

Each `IRC::Client::Server` object has a label that was given to it during
the creation of `IRC::Client` object. `IRC::Client::Server` objects stringify
to the value of their labels and methods that can take an
`IRC::Client::Server` object can also take a `Str` with the label of that server
instead.

### Methods and Attributes

#### `.label`

The label of this server.

#### `.channels`

A list of `Str` or `Pair` containing all the channels the client is in on this
server. Pairs represent channels with channel passwords, where the key is
the channel and the value is its password.

#### `.nick`

A list of nicks the client uses on this server. If one nick is
taken, next one in the list will be attempted to be used.

#### `.alias`

A list of aliases on this server.

#### `.host`

The host of the server.

#### `.port`

The port of the server.

#### `.password`

The password of the server.

#### `.username`

Our username on this server.

#### `.userhost`

Our hostname on this server.

#### `.userreal`

The "real name" of our client.

#### `.Str`

Affects stringification of the object and makes it stringify to the value
of `.label` attribute.

#### Writable Non-Writable Attributes

The following attributes are writable, however, they are written to by
the internals and the behaviour when writing to them directly is undefined.

##### `.current-nick`

Writable attribute. Our currently-used nick. Will be one of the nicks returned
by `.nicks`.

##### `.is-connected`

Writable `Bool` attribute. Indicates whether we're currently in a state
where the server considers us connected. This defaults to `False`, then is set
to `True` when the server sends us `001` IRC command and set back to `False`
when the socket connection breaks.

##### `.has-quit`

Writable `Bool` attribute. Set to `True` when `.quit` method is called
on the Client Object and is used by the socket herder to determine whether
or not the socket connection was cut intentionally.

##### `.has-quit`

Writable `IO::Socket::Async` attribute. Contains an object representing
the socket connected to the server, although it may already be closed.

---

## Client Object (`IRC::Client`)

The Client Object is the heart of this module. The `IRC::Client` you instantiate
and `.run`. The running Client Object is available to your plugins via
`.irc` attribute that you can obtain by doing the `IRC::Client::Plugin` role
or via `.irc` attribute on Message Objects your event handler receives.

The client object's method let you control the client: e.g. joining or parting
channels, changing nicks, banning users, or sending text messages.

### Methods and Attributes

#### `.join`

```perl6
    $.irc.join: <#foo #bar #ber>, :$server;
```

Causes the client join the provided channels.
If `:server` named argument is given, will operate only on that server;
otherwise operates on all connected servers.

#### `.new`

```perl6
my $irc = IRC::Client.new:
    :debug
    :host<irc.freenode.net>
    :6667port
    :password<s3cret>
    :channels<#perl #perl6 #rust-lang>
    :nick<MahBot>
    :alias('foo', /b.r/)
    :username<MahBot>
    :userhost<localhost>
    :userreal('Mah awesome bot!')
    :servers(
        freenode => %(),
        local    => %( :host<localhost> ),
    )
    :plugins(
        class { method irc-to-me ($ where /42/) { 'The answer to universe!' } }
    )
    :filters(
        -> $text where .lines > 5 or .chars > 300 { "Text is too big!!!" }
    )
```

Instantiates a new `IRC::Client` object. Takes the following named arguments:

##### `:channels`

```perl6
    :channels('#perl6bot', '#zofbot', '#myown' => 's3cret')
```

A list of `Str` or `Pair` containing the channels to join.
Pairs represent channels with channel passwords, where the key is
the channel and the value is its password.
**Defaults to:** `#perl6`

##### `:debug`

Takes an `Int`. When set to a positive number, causes debug output to be
generated. Install optional
[Terminal::ANSIColor]https://modules.perl6.org/repo/Terminal::ANSIColor] to
make output colourful. Debug levels:

* `0`—no debug output
* `1`—basic debug output
* `2`—also include list of emitted events
* `3`—also include `irc-all` in the list of emitted events

**Defaults to:** `0`

##### `:filters`

Takes a list of `Callable`s. Will attempt to call them for replies to
`PRIVMSG` and `NOTICE` events if the signatures accept `($text)` or
`($text, :$where)` calls, where `$text` is the reply text and `:$where` is
a named argument of the destination of the reply (either a user or a channel
name).

Callables with `:$where` in the signature must return two values: the new
text to reply with and the location. Otherwise, just one value needs to
be returned: the new text to reply with.

**By default** not specified.

##### `:host`

The hostname of the IRC server to connect to.
**Defaults to:** `localhost`

##### `:nick`

A list of nicknames to use. If set to just one value will automatically
generate three additional nicknames that have underscores appended
(e.g. `P6Bot`, `P6Bot_`, `P6Bot__`, `P6Bot___`).

If one of the given nicks is in use, the client will attempt to use the
next one in the list.

##### `:alias`

**Defaults to:** `P6Bot`

```perl6
    :alias('foo', /b.r/)
```

A list of `Str` or `Regex` objects that in the context of
`irc-addressed`, `irc-to-me`, and `irc-mentioned` events will be used
as alternative nicks. In other words, specifying `'bot'` as alias will allow
you to address the bot using `bot` nick, regardless of the actual nick the
bot is currently using.

**Defaults to:** empty list

##### `:password`

The server password to use. On some networks (like Freenode), the server
password also functions as NickServ's password.
**By default** not specified.

##### `:plugins`

Takes a list of instantiated objects or type objects that implement the
functionality of the system. See [basics tutorial](01-basics.md) and
[event reference](02-event-reference.md) for more information on how
to implement plugin classes.

**By default** not specified.

##### `:port`

The port of the IRC server to connect to. Takes an `Int` between 0 and 65535.
**Defaults to:** `6667`

##### `:servers`

Takes an `Assosiative` with keys as labels of servers and values with
server-specific configuration. Valid keys in the configuration are
`:host`, `:port`, `:password`, `:channels`, `:nick`, `:username`,
`:userhost`, and `:userreal`. They take the same values as same-named arguments
of the `IRC::Client.new` method and if any key is omitted, the value
of the `.new`'s argument will be used.

If `:servers` is not specified, then a server will be created with the
label `_` (underscore).

**By default** not specified.

##### `:username`

The IRC username to use. **Defaults to:** `Perl6IRC`

##### `:userhost`

The hostname of your client. **Defaults to:** `localhost` and can probably
be left as is, unless you're having issues connecting.

##### `:userreal`

The "real name" of your client. **Defaults to:** `Perl6 IRC Client`

----

#### `.nick`

```perl6
    $.irc.nick: 'MahBot', :$server;
    $.irc.nick: <MahBot MahBot2 MahBot3 MahBot4 MahBot5>, :$server;
```

Causes the client to change its nick to the one provided and uses this
as new value of `.current-nick` and `.nick` attributes of the appropriate
`IRC::Client::Server` object. If only one nick
is given, another 3 nicks will be automatically generated by appending
a number of underscores. Will automatically retry nicks further in the list
if the currently attempted one is already in use.

If `:server` named argument is given, will operate only on that server;
 otherwise operates on all connected servers.

#### `.part`

```perl6
    $.irc.part: <#foo #bar #ber>, :$server;
```

Causes the client part the provided channels.
If `:server` named argument is given, will operate only on that server;
otherwise operates on all connected servers.

#### `.quit`

```perl6
    $.irc.quit;
    $.irc.quit: :$server;
```

Causes the client to quit the IRC server.
If `:server` named argument is given, will operate only on that server;
otherwise operates on all connected servers.

#### `.run`

Takes no arguments. Runs the IRC client, causing it to connect to servers
and do all of its stuff. Returns only if all of the servers the client connects
to have been explicitly `.quit` from.

#### `.send`

```perl6
    $.irc.send: :where<Zoffix> :text<Hello!>;
    $.irc.send: :where<#perl6> :text('I ♥ Perl 6!');
    $.irc.send: :where<Senpai> :text('Notice me!') :notice :$server;
```

Sends a `:text` message to `:where`, using either a `PRIVMSG` or `NOTICE`.
The `:where` can be either a user's nick or a channel name. If `:notice`
argument is set to a `True` value will use `NOTICE` otherwise will use
`PRIVMSG` (if you just want to send text to channel like you'd normally
do when talking with regular IRC clients, that'd be the `PRIVMSG` messages).

If `:server` named argument is given, will operate only on that server;
otherwise operates on all connected servers.

**NOTE:** calls to `.send` when server is not connected yet will be
**semi-silently ignored** (only debug output will mention that they were
ignored). This is done on purpose, to prevent `.send` calls from interfering
with the connection negotiation during server reconnects. Although not
free from race conditions, you can mitigate this issue by checking the
`.is-connected` attribute on the appropriate `IRC::Client::Server` object
before attempting the `.send`

## Up Next

Read [Big Picture behaviour](04-big-picture-behaviour.md) next.
