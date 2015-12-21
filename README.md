[![Build Status](https://travis-ci.org/zoffixznet/perl6-IRC-Client.svg)](https://travis-ci.org/zoffixznet/perl6-IRC-Client)

# NAME

IRC::Client - Extendable Internet Relay Chat client

# SYNOPSIS

## Client script

```perl6
    use IRC::Client;
    use IRC::Client::Plugin::Debugger;

    IRC::Client.new(
        :host('localhost'),
        :debug,
        plugins => [ IRC::Client::Plugin::Debugger.new ]
    ).run;
```

## Custom plugins

### Basic response to an IRC command:

The plugin chain handling the message will stop after this plugin.

```
unit class IRC::Client::Plugin::PingPong is IRC::Client::Plugin;
method irc-ping ($irc, $msg) { $irc.ssay("PONG {$irc.nick} $msg<params>[0]") }
```

### More involved handling

On startup, start sending message `I'm an annoying bot` to all channels
every five seconds. We also subscribe to all events and print some debugging
info. By returning a special constant, we tell other plugins to continue
processing the data.

```
use IRC::Client::Plugin; # import constants
unit class IRC::Client::Plugin::Debugger is IRC::Client::Plugin;

method register($irc) {
    Supply.interval( 5, 5 ).tap({
        $irc.privmsg($_, "I'm an annoying bot!")
            for $irc.channels;
    })
}

method all-events ($irc, $e) {
    say "We've got a private message"
        if $e<command> eq 'PRIVMSG' and $e<params>[0] eq $irc.nick;

    # Store arbitrary data in the `pipe` for other plugins to use
    $e<pipe><respond-to-notice> = True
        if $e<command> eq 'PRIVMSG';

    say $e, :indent(4);
    return IRC_NOT_HANDLED;
}

```

# DESCRIPTION

***Note: this is a preview dev release. Things might change and new things
might get added rapidly. The first stable version is currently planned
to appear by January 3, 2016***

This modules lets you create
[IRC clients](https://en.wikipedia.org/wiki/Internet_Relay_Chat)
in Perl 6. The plugin system lets you work on the behaviour, without worrying
about IRC layer.

# METHODS

## `new`

```perl6
my $irc = IRC::Client.new;
```

```perl6
# Defaults are shown
my $irc = IRC::Client.new(
    debug             => False,
    host              => 'localhost',
    port              => 6667,
    nick              => 'Perl6IRC',
    username          => 'Perl6IRC',
    userhost          => 'localhost',
    userreal          => 'Perl6 IRC Client',
    channels          => ['#perl6bot'],
    plugins           => [],
    plugins-essential => [ IRC::Client::Plugin::PingPong.new ],
);
```

Creates and returns a new `IRC::Client` objects. All arguments are optional
and are as follows:

### `debug`

```perl6
    debug => True,
```
Takes `True` and `False` values. When set to `True`, debugging information
will be printed by the modules on the STDOUT. **Defaults to:** `False`

### `host`

```perl6
    host => 'irc.freenode.net',
```
Specifies the hostname of the IRC server to connect to. **Defaults to:**
`localhost`

### `port`

```perl6
    port => 7000,
```
Specifies the port of the IRC server to connect to. **Defaults to:** `6667`

### `nick`

```perl6
    nick => 'Perl6IRC',
```
Specifies the nick for the client to use. **Defaults to:** `Perl6IRC`

### `username`

```perl6
    username => 'Perl6IRC',
```
Specifies the username for the client to user. **Defaults to:** `Perl6IRC`

### `userhost`

```perl6
    userhost => 'localhost',
```
Specifies the hostname for the client to use when sending messages.
**Defaults to:** `localhost` (Note: it's probably safe to leave this at
default. Currently, this attribute is fluid and might be changed or
removed in the future).

### `userreal`

```perl6
    userreal => 'Perl6 IRC Client',
```
Specifies the "real name" of the client. **Defaults to:** `Perl6 IRC Client`

### `channels`

```perl6
    channels => ['#perl6bot'],
```
Takes an array of channels for the client to join. **Defaults to:**
`['#perl6bot']`

### `plugins`

```perl6
    plugins => [ IRC::Client::Plugin::Debug.new ],
```
Takes an array of IRC::Client Plugin objects. To run while the client is
connected.

### `plugins-essential`

```perl6
    plugins-essential => [ IRC::Client::Plugin::PingPong.new ],
```
Same as `plugins`. The only difference is something will be set to
these by default, as these plugins are assumed to be essential to proper
working order of any IRC client. **Defaults to:**
`[ IRC::Client::Plugin::PingPong.new ]`

## `run`

    $irc.run;

Takes no arguments. Starts the IRC client. Exits when the connection
to the IRC server ends.

# INCLUDED PLUGINS

Currently, this distribution comes with two IRC Client plugins:

## IRC::Client::Plugin::Debugger

```perl6
    use IRC::Client;
    use IRC::Client::Plugin::Debugger;

    IRC::Client.new(
        :host('localhost'),
        :debug,
        plugins => [ IRC::Client::Plugin::Debugger.new ]
    ).run;
```

When run, it will pretty-print all of the events received by the client. It
does not stop plugin processing loop after handling a message.

## IRC::Client::Plugin::PingPong

```perl6
    use IRC::Client;
    IRC::Client.new.run; # automatically included in plugins-essential
```

This plugin makes IRC::Client respond to server's C<PING> messages and is
included in the [`plugins-essential`](#plugins-essential) by default.

# EXTENDING IRC::Client / WRITING YOUR OWN PLUGINS

## Overview of the plugin system

The core IRC::Client receives and parses IRC protocol messages from the
server that it then passes through a plugin chain. The plugins declared in
[`plugins-essential`](#plugins-essential) are executed first, followed by
plugins in [`plugins`](#plugins). The order is the same as the order specified
in those two lists.

A plugin can return a [special constant](#return-value-constants) that
indicates it handled the message and the plugin chain processing should stop.

To subscribe to handle a particular IRC command, a plugin simply declares a
method `irc-COMMAND`, where `COMMAND` is the name of the IRC command the
plugin wishes to handle. There are also a couple of
[special events](#special-events) the plugin can subscribe to, such as
intialization during start up or when the client receives a private message
or notice.

## Return value constants

```perl6
    use IRC::Client::Plugin;
    unit class IRC::Client::Plugin::Foo is IRC::Client::Plugin;
    ...
```

To make the constants available in your class, simply `use` IRC::Client::Plugin
class.

### `IRC_HANDLED`

```perl6
    # Returned by default
    method irc-ping ($irc, $e) { $irc.ssay("PONG {$irc.nick} $e<params>[0]") }

    # Explicit return
    method irc-privmsg ($irc, $e) { return IRC_HANDLED; }
```
Specifies that plugin handled the message and the plugin chain processing
should stop immediatelly. Plugins later in the chain won't know this
message ever came. Unless you explicitly return
[`IRC_NOT_HANDLED`](#IRC_NOT_HANDLED) constant, IRC::Client will assume
`IRC_HANDLED` was returned.

### `IRC_NOT_HANDLED`

```perl6
    return IRC_NOT_HANDLED;
```
Returning this constant indicates to IRC::Client that your plugin did
not "handle" the message and it should be propagated further down the
plugin chain for other plugins to handle.



```perl6
    unit class IRC::Client::Plugin::Foo:ver<1.001001>;

    multi method msg () { True }
    multi method msg ($irc, $msg) {
        $irc.privmsg( Zoffix => Dump $msg, :indent(4) );
    }

    multi method interval () {  6  }
    multi method interval ($irc) {
        $irc.privmsg(
            $irc.channels[0], "5 seconds passed. Time is now " ~ now
        );
    }
```

Above is a sample plugin. You can choose to respond either to server
messages or do things at a specific interval.

### Responding to server messages

```perl6
    multi method msg () { True }
    multi method msg ($irc, $msg) {
        $irc.privmsg( Zoffix => Dump $msg, :indent(4) );
    }
```

If your plugin can resond to server messages, declare two multi methods
`msg` as seen above. The one without parameters needs to return `True`
(or `False`, if your plugin does not respond to messages). The second
gets the `IRC::Client` object as the first argument and the parsed message
as the second argument.

### Acting in intervals

```perl6
    multi method interval () {  6  }
    multi method interval ($irc) {
        $irc.privmsg(
            $irc.channels[0], "5 seconds passed. Time is now " ~ now
        );
    }
```
Your plugin can also repsond in intervals. Declare an `interval` multi
that takes no arguments and returns an interval in seconds that your
action should happen in (return `0` if your plugin does not handle intervals).
The other multi method `interval` takes the `IRC::Client` as the argument.

## Methods for plugins

You can make use of these `IRC::Client` methods in your plugins:

### `.ssay`

```perl6
    $irc.ssay("Foo bar!");
```
Sends a message to the server, automatically appending `\r\n`.

### `.privmsg`

```perl6
    $irc.privmsg( Zoffix => "Hallo!" );
```
Sends a `PRIVMSG` message specified in the second argument
to the user/channel specified as the first argument.

# REPOSITORY

Fork this module on GitHub:
https://github.com/zoffixznet/perl6-IRC-Client

# BUGS

To report bugs or request features, please use
https://github.com/zoffixznet/perl6-IRC-Client/issues

# AUTHOR

http://zoffix.com/

# LICENSE

You can use and distribute this module under the terms of the
The Artistic License 2.0. See the `LICENSE` file included in this
distribution for complete details.
