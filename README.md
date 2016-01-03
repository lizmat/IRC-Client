[![Build Status](https://travis-ci.org/zoffixznet/perl6-IRC-Client.svg)](https://travis-ci.org/zoffixznet/perl6-IRC-Client)

# NAME

IRC::Client - Extendable Internet Relay Chat client

# TABLE OF CONTENTS
- [NAME](#name)
- [TABLE OF CONTENTS](#table-of-contents)
- [SYNOPSIS](#synopsis)
    - [Client script](#client-script)
    - [Custom plugins](#custom-plugins)
        - [Basic response to an IRC command:](#basic-response-to-an-irc-command)
        - [More involved handling](#more-involved-handling)
- [DESCRIPTION](#description)
- [BLEED BRANCH](#bleed-branch)
- [METHODS](#methods)
    - [`new`](#new)
        - [`debug`](#debug)
        - [`host`](#host)
        - [`password`](#password)
        - [`port`](#port)
        - [`nick`](#nick)
        - [`username`](#username)
        - [`userhost`](#userhost)
        - [`userreal`](#userreal)
        - [`channels`](#channels)
        - [`plugins`](#plugins)
        - [`plugins-essential`](#plugins-essential)
    - [`run`](#run)
- [METHODS FOR PLUGINS](#methods-for-plugins)
    - [`.notice`](#notice)
    - [`.privmsg`](#privmsg)
    - [`.respond`](#respond)
        - [`where`](#where)
        - [`what`](#what)
        - [`how`](#how)
        - [`who`](#who)
    - [`.ssay`](#ssay)
- [INCLUDED PLUGINS](#included-plugins)
    - [IRC::Client::Plugin::Debugger](#ircclientplugindebugger)
    - [IRC::Client::Plugin::PingPong](#ircclientpluginpingpong)
- [EXTENDING IRC::Client / WRITING YOUR OWN PLUGINS](#extending-ircclient--writing-your-own-plugins)
    - [Overview of the plugin system](#overview-of-the-plugin-system)
    - [Return value constants](#return-value-constants)
        - [`IRC_HANDLED`](#irc_handled)
        - [`IRC_NOT_HANDLED`](#irc_not_handled)
    - [Subscribing to IRC events](#subscribing-to-irc-events)
        - [Standard IRC commands](#standard-irc-commands)
    - [Special Events](#special-events)
        - [`irc-start-up`](#irc-start-up)
        - [`irc-connected`](#irc-connected)
        - [`irc-all-events`](#irc-all-events)
        - [`irc-to-me`](#irc-to-me)
        - [`irc-privmsg-me`](#irc-privmsg-me)
        - [`irc-notice-me`](#irc-notice-me)
        - [`irc-unhandled`](#irc-unhandled)
    - [Contents of the parsed IRC message](#contents-of-the-parsed-irc-message)
        - [`command`](#command)
        - [`params`](#params)
        - [`pipe`](#pipe)
        - [`who`](#who-1)
- [REPOSITORY](#repository)
- [BUGS](#bugs)
- [AUTHOR](#author)
- [LICENSE](#license)

# SYNOPSIS

## Client script

```perl6
    use IRC::Client;
    use IRC::Client::Plugin::Debugger;

    IRC::Client.new(
        :host<localhost>
        :channels<#perl6bot #zofbot>
        :debug
        :plugins( IRC::Client::Plugin::Debugger.new )
    ).run;
```

## Custom plugins

### Basic response to an IRC command:

The plugin chain handling the message will stop after this plugin.

```perl6
unit class IRC::Client::Plugin::PingPong is IRC::Client::Plugin;
method irc-ping ($irc, $e) { $irc.ssay("PONG {$irc.nick} $e<params>[0]") }
```

### More involved handling

On startup, start sending message `I'm an annoying bot` to all channels
every five seconds. We also subscribe to all events and print some debugging
info. By returning a special constant, we tell other plugins to continue
processing the data.

```perl6
use IRC::Client::Plugin; # import constants
unit class IRC::Client::Plugin::Debugger is IRC::Client::Plugin;

method irc-connected($irc) {
    Supply.interval( 5, 5 ).tap({
        $irc.privmsg($_, "I'm an annoying bot!")
            for $irc.channels;
    })
}

method irc-all-events ($irc, $e) {
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

***Note: this is module is currently experimental. Things might change and
new things will get added rapidly.***

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
    password          => 's3cret',
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

### `password`

```perl6
    password => 's3cret',
```
Specifies the password for the IRC server. (on Freenode, for example, this
is the NickServ password that identifies to services). **Defaults to:** no
password.

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

# METHODS FOR PLUGINS

You can make use of these `IRC::Client` methods in your plugins:

## `.notice`

```perl6
    $irc.notice( 'Zoffix', 'Hallo!' );
```
Sends a `NOTICE` message specified in the second argument
to the user/channel specified as the first argument.

## `.privmsg`

```perl6
    $irc.privmsg( 'Zoffix', 'Hallo!' );
```
Sends a `PRIVMSG` message specified in the second argument
to the user/channel specified as the first argument.

## `.respond`

```perl6
    $irc.respond:
        :where<#zofbot>
        :what("Hallo how are you?! It's been 1 hour!")
        :how<privmsg>
        :who<Zoffix>
        :when( now + 3600 )
    ;
```
Generates a response based on the provided arguments, which are as follows:

### `where`

```perl6
    $irc.respond: :where<Zoffix> ...
    $irc.respond: :where<#zofbot> ...
```
**Mandatory**. Takes either a nickname or a channel name where to
send the message to.

### `what`

```perl6
    $irc.respond: :what('Hallo how are you?!') ...
```
**Mandatory**. Takes a string, which is the message to be sent.

### `how`

```perl6
    $irc.respond: :how<privmsg> ...
    $irc.respond: :how<notice> ...
```
**Optional**. Specifies whether the message should be sent using
`PRIVMSG` or `NOTICE` IRC commands. **Valid values** are `privmsg` and `notice`
(case-insensitive).

### `who`

```perl6
    $irc.respond: :who<Zoffix> ...
```
**Optional**. Takes a string with a nickname (which doesn't need to be
valid in any way). If the `where` argument is set to a name of a channel,
then the method will modify the `what` argument, by prepending
`$who, ` to it.

### `when`

```perl6
    $irc.respond: :when(now+5) ... # respond in 5 seconds
    $irc.respond: :when(DateTime.new: :2016year :1month :2day) ...
```
**Optional**. Takes a `Dateish` or `Instant` value that specifies when the
response should be generated. If omited, the response will be generated
as soon as possible. **By default** is not specified.

## `.ssay`

```perl6
    $irc.ssay("Foo bar!");
```
Sends a message to the server, automatically appending `\r\n`. Mnemonic:
**s**erver **say**.

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
[`IRC_NOT_HANDLED`](#irc_not_handled) constant, IRC::Client will assume
`IRC_HANDLED` was returned.

### `IRC_NOT_HANDLED`

```perl6
    return IRC_NOT_HANDLED;
```
Returning this constant indicates to IRC::Client that your plugin did
not "handle" the message and it should be propagated further down the
plugin chain for other plugins to handle.

## Subscribing to IRC events

### Standard IRC commands

```perl6
    method irc-privmsg ($irc, $e) { ... }
    method irc-notice  ($irc, $e) { ... }
    method irc-353     ($irc, $e) { ... }
```
To subscribe to an IRC event, simply declare a method named `irc-command`,
where `command` is the IRC command you want to handle, in **lower case**.
The method takes two positional arguments: an `IRC::Client` object and
the [parsed IRC message](#contents-of-the-parsed-irc-message).

You'll likely generate a response based on the content of the parsed message
and use one of the [METHODS FOR PLUGINS](#methods-for-plugins) to send that
response.

## Special Events

```perl6
    method irc-start-up   ($irc) { ... } # once per client run
    method irc-connected  ($irc) { ... } # once per server connection

    method irc-all-events ($irc, $e) { ... }
    method irc-to-me      ($irc, $e) { ... }
    method irc-privmsg-me ($irc, $e) { ... }
    method irc-notice-me  ($irc, $e) { ... }
    ... # all other handlers for standard IRC commands
    method irc-unhandled  ($irc, $e) { ... }
```
In addition to the [standard IRC commands](#standard-irc-commands), you can
register several special cases. They're handled in the event chain in the order
shown above (except for [`irc-start-up`](#irc-start-up) and
[`irc-connected`](#irc-connected) that do not offect command-triggered events).
That is, if a plugin returns [`IRC_HANDLED`](#irc_handled) after
processing, say, [`irc-all-events`](#irc-all-events) event, its
[`irc-notice-me`](#irc-notice-me) handler won't be triggered, even if it would
otherwise.

The available special events are as follows:

### `irc-start-up`

```perl6
    method irc-start-up ($irc) { ... }
```
Passed IRC::Client object as the only argument. Triggered right when the
IRC::Client is [`.run`](#run), which means most of
[METHODS FOR PLUGINS](#methods-for-plugins) **cannot** be used, as no connection
has been made yet. This event will be issued only once per [`.run`](#run)
and the method's return value is discarded.

### `irc-connected`

```perl6
    method irc-connected ($irc) { ... }
```
Passed IRC::Client object as the only argument. Triggered right when we
get a connection to the server, identify with it and issue `JOIN` commands
to enter the channels. Note that at this point it is not guaranteed that the
client is already in all the channels it's meant to join.
This event will be issued only once per connection to the server
and the method's return value is discarded.

### `irc-all-events`

```perl6
    method irc-all-events ($irc, $e) { ... }
```
Triggered for all IRC commands received, regardless of their content. As this
method will be triggered before any others, you can use this to
pre-process the message, for example. ***WARNING:*** **since
[`IRC_HANDLED` constant](#irc_handled) is returned by default, if you do not
explicitly return [`IRC_NOT_HANDLED`](#irc_not_handled), your client will
stop handling ALL other messages
***

### `irc-to-me`

```perl6
    method irc-to-me ($irc, $e, %res) {
        $irc.respond: |%res, :what("You told me: %res<what>");
    }
```
Triggered when: the IRC `PRIVMSG` command is received, where the recipient
is the client (as opposed to some channel); the `NOTICE` command is
received, or the `PRIVMSG` command is received, where the recipient is the
channel and the message begins with client's nickname (i.e. the client
was addressed in channel.

Along with `IRC::Client` object and the event
hash contained in `$e`, this method also receives an additional positional
argument that is a hash containing the correct `$where`, `$who`, `$how`, and
`$what` arguments to generate a response using [`.respond method`](#respond).
You'll likely want to change the `$what` argument. You can do that by
specifying `:what('...')` after slipping the `|%res`, as shown in the example
above.

Also, note: the supplied `$what` argument will have the client's
nickname removed from it. Use the params in `$e` if you want the exact message
that was said.

### `irc-privmsg-me`

```perl6
    method irc-privmsg-me ($irc, $e) { ... }
```
Triggered when the IRC `PRIVMSG` command is received, where the recipient
is the client (as opposed to some channel).

### `irc-notice-me`

```perl6
    method irc-notice-me ($irc, $e) { ... }
```
Triggered when the IRC `NOTICE` command is received, where the recipient
is the client (as opposed to some channel).

### `irc-unhandled`

```perl6
    method irc-unhandled ($irc, $e) { ... }
```

This is the same as [`irc-all-events`](#irc-all-events), except it's triggered
**after** all other events were tried. This method can be used to catch
any unhandled events.

## Contents of the parsed IRC message

```perl6
    # method irc-366 ($irc, $e) { ... }
    {
        command => "366".Str,
        params  => [
            "Perl6IRC".Str,
            "#perl6bot".Str,
            "End of NAMES list".Str,
        ],
        pipe    => { },
        who     => {
            host => "irc.example.net".Str,
        },
    }

    # method irc-join ($irc, $e) { ... }
    {
        command => "JOIN".Str,
        params  => [
            "#perl6bot".Str,
        ],
        pipe    => { },
        who     => {
            host => "localhost".Str,
            nick => "ZoffixW".Str,
            user => "~ZoffixW".Str,
        },
    }

    # method irc-privmsg ($irc, $e) { ... }
    {
        command => "PRIVMSG".Str,
        params  => [
            "#perl6bot".Str,
            "Perl6IRC, hello!".Str,
        ],
        pipe    => { },
        who     => {
            host => "localhost".Str,
            nick => "ZoffixW".Str,
            user => "~ZoffixW".Str,
        },
    }

    # method irc-notice-me ($irc, $e) { ... }
    {
        command => "NOTICE".Str,
        params  => [
            "Perl6IRC".Str,
            "you there?".Str,
        ],
        pipe    => { },
        who     => {
            host => "localhost".Str,
            nick => "ZoffixW".Str,
            user => "~ZoffixW".Str,
        },
    }
```

The second argument to event handlers is the parsed IRC message that is a
hash with the following keys:

### `command`

```perl6
    command => "NOTICE".Str,
```
Contains the IRC command this message represents.

### `params`

```perl6
    params  => [
        "Perl6IRC".Str,
        "you there?".Str,
    ],
```
Constains the array of parameters for the IRC command.

### `pipe`

```perl6
    pipe => { },
```
This is a special key that can be used for communication between plugins.
While any plugin can modify any key of the parsed command's hash, the provided
`pipe` hash is simply a means to provide some standard, agreed-upon name
of a key to pass information around.

### `who`

```perl6
    #fdss
    who => {
        host => "localhost".Str,
        nick => "ZoffixW".Str,
        user => "~ZoffixW".Str,
    },

    who => {
        host => "irc.example.net".Str,
    },
```
A hash containing information on who sent the message. Messages sent by the
server do not have `nick`/`user` keys specified.

# REPOSITORY

Fork this module on GitHub:
https://github.com/zoffixznet/perl6-IRC-Client

# BUGS

To report bugs or request features, please use
https://github.com/zoffixznet/perl6-IRC-Client/issues

# AUTHOR

Zoffix Znet (http://zoffix.com/)

# LICENSE

You can use and distribute this module under the terms of the
The Artistic License 2.0. See the `LICENSE` file included in this
distribution for complete details.
