[[back to doc map]](README.md)

# Basics Tutorial

## Table of Contents

- [Blog Tutorial](#blog-tutorial)
- [Subscribing to Events](#subscribing-to-events)
    - [Event Handler Input](#event-handler-input)
- [Responding to Events](#responding-to-events)
    - [Example: Echo Bot](#example-echo-bot)
- [Generating Messages](#generating-messages)
- [Up Next](#up-next)

----

This tutorial covers basic usage of `IRC::Client`, without going into
[all of the supported events](02-event-reference.md) or describing
[all of the methods](03-method-reference.md) or [available Message
Objects](04-message-objects.md). This should be enough
if you're just bringing some functionality using IRC as your interface, rather
than making, say, a full-featured IRC client.

## Blog Tutorial

There exists a blog post describing this bot and showcasing some of the
more advanced features. You can find it at [*yet to be published*](#).

## Subscribing to Events

All of the functionality is implemented as "plugins," which are passed to
the `:plugins` attribute. Plugins are just regular classes, altough they can
do the `IRC::Client::Plugin` role to obtain extra functionality.

To subscribe to one of [the events](02-event-reference.md), simply
create a method with event's name in your class. The tutorial will use the
`irc-to-me` event, which is a convenience event fired when the bot is addressed
in-channel or someone sends it a notice or a private message.

### Event Handler Input

The event handlers receive one positional argument, which is an object
that does `IRC::Client::Message` role. The actual object received depends
on the event that triggered the handler. For example, the `irc-to-me` can
receive these message objects:

```perl6
    IRC::Client::Message::Privmsg::Me
    IRC::Client::Message::Privmsg::Channel
    IRC::Client::Message::Notice::Me
    IRC::Client::Message::Notice::Channel
```

While message objects differ in methods they offer, all of the above do have
a `.text` attribute and stringify to its value. This means we can add a type
constraint on it without having to explicitly call it:

```perl6
    method irc-to-me ($e where /'bot command'/) { 'Do things here!'; }
```

## Responding to Events

Channel messages, private messages, and notices can be replied to. Their
message objects have a `.reply` method you can call to send a reply to the
message's sender, however it's easier to just return a value from your method
handler, which will automatically call `.reply` on the message object for you.

Returning a value from your event handler singnals to the Client Object that
it handled the event and no other plugins or event handlers should be tried.
Your plugin can do the `IRC::Client::Plugin` role (automatically exported
when you `use IRC::Client`), which provides `$.NEXT` attribute. The value
of that attribute is special and returning it signals the Client Object
that your event handler did **not** handle the event and other plugins and
event handlers should be tried.

Here are the things your event handler can return:

* Value of `$.NEXT`: pass the event to the next plugin or event handler than can
handle it
* `Nil` (and a select few other items that don't make sense as replies, such as
`IRC::Client` object): do not reply to the message, but do not pass the event to
any other event handler; we handled it
* `Promise`: when the Promise is `.kept`, use its value for the .reply, unless
it's a `Nil`. **Note:** you cannot return `$.NEXT` here.
* *Any other value*: mark the event as handled and don't pass it further. The
returned value will be given to message object's `.reply` method if
it has one, or ignored if it doesn't. For `irc-to-me` message objects, this
means the value will be sent back to the sender of the original message

### Example: Echo Bot

In this example, we subscribe to the `irc-to-me` event and respond by returning
the original message, prefixed with `You said `.

```perl6
    use IRC::Client;

    .run with IRC::Client.new:
        :host<irc.freenode.net>
        :channels('#perl6bot', '#zofbot', '#myown' => 's3cret')
        :debug
        :plugins(
            class { method irc-to-me ($e) { "You said $e.text()"} }
        )
```

## Generating Messages

If your plugin needs to generate messages instead of merely responding to
commands, you can use the Client Object's `.send` method. Your plugin needs
to do the `IRC::Client::Plugin` role to get access to the Client Object via
the `$.irc` attribute:

```perl6
use IRC::Client;

class AlarmBot does IRC::Client::Plugin {
    method irc-connected ($) {
        react {
            whenever Supply.interval(3) {
                $.irc.send: :where<#perl6> :text<Three seconds passed!>;
            }
        }
    }
}

.run with IRC::Client.new:
    :nick<MahBot>
    :host<irc.freenode.net>
    :channels<#perl6>
    :debug
    :plugins(AlarmBot.new)
```

Here, we subscribe to `irc-connected` event (using an anonymous parameter
for its message object, since we don't need it). It fires whenever we
successfully connect to a server. In the event handler we setup a
`react`/`whenever` loop, with a `Supply` generating an event every three
seconds. In the `whenever` block, we use the `$.irc` attribute provided
by the `IRC::Client::Plugin` role to call method `.send` on the Client Object.
In the `:where` parameter, we specify we want to send the message to
channel `#perl6` and the `:text` parameter contains the text we want to send.
The bot will send that text every 3 seconds.

## Up Next

Read [the event reference](02-event-reference.md) next.
