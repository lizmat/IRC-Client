[[back to main docs]](../README.md#documentation-map)

# Event Reference

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

                  irc-connected  ▶  irc-numeric          ▶  irc-XXX      ▶  irc-all
                                    irc-numeric          ▶  irc-XXX      ▶  irc-all

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
irc-addressed  ▶  irc-to-me      ▶  irc-privmsg-channel  ▶  irc-privmsg  ▶  irc-all
irc-addressed  ▶  irc-to-me      ▶  irc-notice-channel   ▶  irc-notice   ▶  irc-all
```

This event chain is triggered when the client is addressed in channel either
via a `PRIVMSG` or `NOTICE` IRC message. 'Addressed' means the message line
starts with the current nickname of the client, followed by single whitespace character, `;`, or `,` characters, followed by any number of whitespace; or
in regex terms, matches `/^ $nick <[,:\s]> \s* /`. This prefix portion will be
**stripped** from the actual message.

Possible message objects received by event handler:
`IRC::Client::Message::Privmsg::Channel` or
`IRC::Client::Message::Notice::Channel`

### `irc-mentioned`

```
irc-mentioned  ▶  irc-privmsg-channel  ▶  irc-privmsg  ▶  irc-all
irc-mentioned  ▶  irc-notice-channel   ▶  irc-notice   ▶  irc-all
```

Possible message objects received by event handler:
`IRC::Client::Message::Privmsg::Channel` or
`IRC::Client::Message::Notice::Channel`

## Up Next

Read [the method reference](03-method-reference.md) next.
