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

## Event Map

All event chains end with `irc-all`, which is not shown in the table below,
for brevity. `irc-XXX` stands for numeric events where `XXX` is a
three-digit number. See [this numerics
table](https://www.alien.net.au/irc/irc2numerics.html) for meaning of codes,
depending on the server used.

```
irc-addressed  ▶  irc-to-me      ▶  irc-privmsg-channel  ▶  irc-privmsg
                  irc-mentioned  ▶  irc-privmsg-channel  ▶  irc-privmsg
                                    irc-privmsg-channel  ▶  irc-privmsg
                  irc-to-me      ▶  irc-privmsg-me       ▶  irc-privmsg

irc-addressed  ▶  irc-to-me      ▶  irc-notice-channel   ▶  irc-notice
                  irc-mentioned  ▶  irc-notice-channel   ▶  irc-notice
                                    irc-notice-channel   ▶  irc-notice
                  irc-to-me      ▶  irc-notice-me        ▶  irc-notice

                                    irc-mode-channel     ▶  irc-mode
                                    irc-mode-me          ▶  irc-mode

                  irc-connected  ▶  irc-numeric          ▶  irc-XXX
                                    irc-numeric          ▶  irc-XXX
```

## Up Next

Read [the method reference](03-method-reference.md) next.
