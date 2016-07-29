[[back to main docs]](../README.md#documentation-map)

# Method Reference

This document describes events available on various objects in use when working
with `IRC::Client`.

## Message Objects

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

## Up Next

Read [the method reference](03-method-reference.md) next.
