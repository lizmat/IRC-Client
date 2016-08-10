[[back to doc map]](README.md)

# Event Reference

## Table of Contents

- [Responding to Events](#responding-to-events)
- [Event Map](#event-map)
- [Event Triggers](#event-triggers)
    - [`irc-addressed`](#irc-addressed)
    - [`irc-all`](#irc-all)
    - [`irc-connected`](#irc-connected)
    - [`irc-join`](#irc-join)
    - [`irc-mentioned`](#irc-mentioned)
    - [`irc-mode`](#irc-mode)
    - [`irc-mode-channel`](#irc-mode-channel)
    - [`irc-mode-me`](#irc-mode-me)
    - [`irc-nick`](#irc-nick)
    - [`irc-notice`](#irc-notice)
    - [`irc-notice-channel`](#irc-notice-channel)
    - [`irc-notice-me`](#irc-notice-me)
    - [`irc-numeric`](#irc-numeric)
    - [`irc-part`](#irc-part)
    - [`irc-privmsg`](#irc-privmsg)
    - [`irc-privmsg-channel`](#irc-privmsg-channel)
    - [`irc-privmsg-me`](#irc-privmsg-me)
    - [`irc-quit`](#irc-quit)
    - [`irc-started`](#irc-started)
    - [`irc-to-me`](#irc-to-me)
    - [`irc-unknown`](#irc-unknown)
    - [`irc-XXX`](#irc-xxx)
- [Up Next](#up-next)

---

The module offers named, numeric, and convenience events. The named and
numeric events correspond to IRC protocol events, while convenience events
are an extra layer provided to make using the module easier. This means one
IRC event can trigger several events of the module. For example, if someone
addresses our bot in a channel, the following chain of events will be fired:

    irc-addressed  ▶  irc-to-me  ▶  irc-privmsg-channel  ▶  irc-privmsg  ▶  irc-all

The events are ordered from "narrowest" to "widest": `irc-addressed` can be
triggered only in-channel, when our bot is addressed; `irc-to-me` can also
be triggered via notice and private message, so it's wider;
`irc-privmsg-channel` includes all channel messages, so it's wider still;
and `irc-privmsg` also includes private messages to our bot. The chain ends
by the widest event of them all: `irc-all`.

## Responding to Events

See [section in Basic Tutorial](01-basics.md#responding-to-events) for
responding by returning a value from the event handler.

The Message Objects received by the event handlers for the `irc-privmsg` and
`irc-notice` event chains also provide a `.reply` method using which you
can reply to the event. When this method is called `.is-replied` attribute
of the Message Object is set to `True`, which signals to the Client Object
that the returned value from the event handler should be discarded.

## Event Map

In the chart below, `irc-XXX` stands for numeric events where `XXX` is a
three-digit number. See [this numerics
table](https://www.alien.net.au/irc/irc2numerics.html) for meaning of codes,
depending on the server used.

```
irc-addressed  ▶  irc-to-me      ▶  irc-privmsg-channel  ▶  irc-privmsg  ▶  irc-all
                  irc-mentioned  ▶  irc-privmsg-channel  ▶  irc-privmsg  ▶  irc-all
                                    irc-privmsg-channel  ▶  irc-privmsg  ▶  irc-all
                  irc-to-me      ▶  irc-privmsg-me       ▶  irc-privmsg  ▶  irc-all

irc-addressed  ▶  irc-to-me      ▶  irc-notice-channel   ▶  irc-notice   ▶  irc-all
                  irc-mentioned  ▶  irc-notice-channel   ▶  irc-notice   ▶  irc-all
                                    irc-notice-channel   ▶  irc-notice   ▶  irc-all
                  irc-to-me      ▶  irc-notice-me        ▶  irc-notice   ▶  irc-all

                                    irc-mode-channel     ▶  irc-mode     ▶  irc-all
                                    irc-mode-me          ▶  irc-mode     ▶  irc-all

                  irc-connected  ▶  irc-XXX              ▶  irc-numeric  ▶  irc-all
                                    irc-XXX              ▶  irc-numeric  ▶  irc-all
                                                            irc-join     ▶  irc-all
                                                            irc-nick     ▶  irc-all
                                                            irc-part     ▶  irc-all
                                                            irc-quit     ▶  irc-all
                                                            irc-unknown  ▶  irc-all

                                                                            irc-started
```

**Note:** `irc-started` is a special event that's exempt from the rules
applicable to all other events and their event handlers:

* It's called just once per call of `IRC::Client`'s `.run` method, regardless
of how many times the client reconnects
* When it's called, there's no guarantee the connections to servers have
been fully established yet or channels joined yet.
* Unless all other event handlers, this one does not take any arguments
* Return values from handlers are ignored and the event is propagated to all of
the plugins
* This event does not trigger `irc-all` event

## Event Triggers

### `irc-addressed`

```
irc-addressed  ▶  irc-to-me  ▶  irc-privmsg-channel  ▶  irc-privmsg  ▶  irc-all
irc-addressed  ▶  irc-to-me  ▶  irc-notice-channel   ▶  irc-notice   ▶  irc-all
```

This event chain is triggered when the client is addressed in a channel either
via a `PRIVMSG` or `NOTICE` IRC message. 'Addressed' means the message line
starts with the current nickname of the client or one of its aliases,
followed by `;` or `,`
characters, followed by any number of whitespace; or
in regex terms, matches `/^ [$nick | @aliases] <[,:]> \s* /`.
This prefix portion will be
**stripped** from the actual message.

Possible message objects received by event handler:

* `IRC::Client::Message::Privmsg::Channel`
* `IRC::Client::Message::Notice::Channel`

### `irc-all`

```
irc-all
```

Triggered on all events, except for the special `irc-started` event.

Possible message objects received by event handler:
* `IRC::Client::Message::Notice::Channel`
* `IRC::Client::Message::Notice::Me`

### `irc-connected`

```
irc-connected  ▶  irc-001  ▶  irc-numeric  ▶  irc-all
```

Triggered on `001` numeric IRC command that indicates we successfully
connected to the IRC server and obtained a nickname. *Note:* it's not
guaranteed that we already joined all the channels when this event is triggered;
in fact, it's more likely that we haven't yet. *Also note:* that in long
running programs this event will be triggered more than once, because the
client automatically reconnects when connection drops, so the event will
be triggered on each reconnect. See also `irc-started`

Receives `IRC::Client::Message::Numeric` message object.

### `irc-join`

```
irc-join  ▶  irc-all
```

Triggered when someone joins a channel we are in. *Note:* typically the
server will generate this event when *we* join a channel too.
Receives `IRC::Client::Message::Join` message object.

### `irc-mentioned`

```
irc-mentioned  ▶  irc-privmsg-channel  ▶  irc-privmsg  ▶  irc-all
irc-mentioned  ▶  irc-notice-channel   ▶  irc-notice   ▶  irc-all
```

This event chain is triggered when the client is mentioned in a channel either
via a `PRIVMSG` or `NOTICE` IRC message. Being mentioned means the message
contains our nick or one of the aliases delimited by word boundaries on both
sides; or in regex terms, matches `/ << [$nick | @aliases] >> /`.

Possible message objects received by event handler:
* `IRC::Client::Message::Privmsg::Channel`
* `IRC::Client::Message::Notice::Channel`

### `irc-mode`

```
irc-mode  ▶  irc-all
```

Triggered when `MODE` commands are performed on the client or on the channel
we are in.

Possible message objects received by event handler:
* `IRC::Client::Message::Mode::Channel`
* `IRC::Client::Message::Mode::Me`

### `irc-mode-channel`

```
irc-mode-channel  ▶  irc-mode  ▶  irc-all
```

Triggered when `MODE` commands are performed on a channel the client is in
Receives `IRC::Client::Message::Mode::Channel` message object.

### `irc-mode-me`

```
irc-mode-me  ▶  irc-mode  ▶  irc-all
```

Triggered when `MODE` commands are performed on the client.
Receives `IRC::Client::Message::Mode::Me` message object.

### `irc-nick`

```
irc-nick  ▶  irc-all
```

Triggered when someone in a channel we are in changes nick.
*Note:* typically the server will generate this event when *we* change
a nick too.
Receives `IRC::Client::Message::Nick` message object.

### `irc-notice`

```
irc-notice  ▶  irc-all
```

Triggered on `NOTICE` messages sent to a channel the client is in or to
the client directly.

Possible message objects received by event handler:
* `IRC::Client::Message::Notice::Channel`
* `IRC::Client::Message::Notice::Me`

### `irc-notice-channel`

```
irc-notice-channel  ▶  irc-notice  ▶  irc-all
```

Triggered on `NOTICE` messages sent to a channel the client is in.
Receives `IRC::Client::Message::Notice::Channel` message object.

### `irc-notice-me`

```
irc-notice-me  ▶  irc-notice  ▶  irc-all
```

Triggered on `NOTICE` messages sent directly to the client.
Receives `IRC::Client::Message::Notice::Me` message object.

### `irc-numeric`

```
irc-numeric  ▶  irc-XXX  ▶  irc-all
```

Triggered on numeric IRC commands.
Receives `IRC::Client::Message::Numeric` message object.

### `irc-part`

```
irc-part  ▶  irc-all
```

Triggered when someone parts (leaves without quitting IRC entirely) a channel
we are in. Receives `IRC::Client::Message::Part` message object.

### `irc-privmsg`

```
irc-privmsg  ▶  irc-all
```

Triggered on `PRIVMSG` messages sent to a channel the client is in or to
the client directly.

Possible message objects received by event handler:
* `IRC::Client::Message::Privmsg::Channel`
* `IRC::Client::Message::Privmsg::Me`

### `irc-privmsg-channel`

```
irc-privmsg-channel  ▶  irc-privmsg  ▶  irc-all
```

Triggered on `PRIVMSG` messages sent to a channel the client is in.
Receives `IRC::Client::Message::Privmsg::Channel` message object.


### `irc-privmsg-me`

```
irc-privmsg-me  ▶  irc-privmsg  ▶  irc-all
```

Triggered on `PRIVMSG` messages sent directly to the client.
Receives `IRC::Client::Message::Privmsg::Me` message object.

### `irc-quit`

```
irc-quit  ▶  irc-all
```

Triggered when someone in a channel we are in quits IRC.
Receives `IRC::Client::Message::Quit` message object.

### `irc-started`

```
irc-started
```

The event is different from all others (see end of `Event Map` section). It's
triggered just once per call of `.run` method on `IRC::Client` object,
regardless of how many times the client reconnects, and it's
called on all of the plugins, regardless of the return value of the
event handler.

Does not receive any arguments.

### `irc-to-me`

```
irc-addressed  ▶  irc-to-me  ▶  irc-privmsg-channel  ▶  irc-privmsg  ▶  irc-all
                  irc-to-me  ▶  irc-privmsg-me       ▶  irc-privmsg  ▶  irc-all

irc-addressed  ▶  irc-to-me  ▶  irc-notice-channel   ▶  irc-notice   ▶  irc-all
                  irc-to-me  ▶  irc-notice-me        ▶  irc-notice   ▶  irc-all
```

This event chain is triggered when the client is addressed in a channel via
a `PRIVMSG` or `NOTICE` IRC message or receives a private or notice
message directly. In cases where the trigger happened due to being addressed
in channel, the prefix used for addressing (nick|aliases + `,` or `.` +
whitespace) will be stripped from the message.

Possible message objects received by event handler:
* `IRC::Client::Message::Privmsg::Channel`
* `IRC::Client::Message::Privmsg::Me`
* `IRC::Client::Message::Notice::Channel`
* `IRC::Client::Message::Notice::Me`

*Note irrelevant to common users:* to avoid spurious triggers during
IRC server connection negotiation, this event does *not* fire until the server
deems the client connected; that is, sends the IRC `001` command.

### `irc-unknown`

```
irc-unknown  ▶  irc-all
```

Triggered when an unknown event is generated. You're not supposed to receive
any of these and receiving one likely indicates a problem with `IRC::Client`.
Please report this [on the Issue
tracker](https://github.com/zoffixznet/perl6-IRC-Client/issues/new),
indicating what server generated such a message and include your code too,
if possible.

Receives `IRC::Client::Message::Unknown` message object.

### `irc-XXX`

**Note:*** `XXX` stands for a three-digit numeric code of the command that
triggered the event, for example `irc-001`. See `irc-numeric` for event trigger
that responds to all numerics.

```
irc-XXX  ▶  irc-numeric  ▶  irc-all
```

Triggered on numeric IRC commands.
Receives `IRC::Client::Message::Numeric` message object.

## Up Next

Read [the method reference](03-method-reference.md) next.
