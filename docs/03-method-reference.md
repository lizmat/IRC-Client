[[back to main docs]](../README.md#documentation-map)

# Method Reference

This document describes events available on various objects in use when working
with `IRC::Client`.

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

A list of strings containing all the channels the client is in on this
server.

#### `.nick`

A list of nicks the client uses on this server. If one nick is
taken, next one in the list will be attempted to be used.

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
## Up Next

Read [the method reference](03-method-reference.md) next.
