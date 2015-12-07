[![Build Status](https://travis-ci.org/zoffixznet/perl6-IRC-Client.svg)](https://travis-ci.org/zoffixznet/perl6-IRC-Client)

# NAME

IRC::Client - Extendable Internet Relay Chat client

# SYNOPSIS

```perl6
    use IRC::Client;
    use IRC::Client::Plugin::Debugger;

    IRC::Client.new(
        :host('localhost'),
        :debug,
        plugins => [ IRC::Client::Plugin::Debugger.new ]
    ).run;
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

# PLUGINS

Currently, this distribution comes with two IRC Client plugins:

## Writing your own

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

## Included Plugins

### `IRC::Client::Plugin::Debugger`

    plugins => [IRC::Client::Plugin::Debugger.new]

Including this plugin will pretty-print parsed IRC messages on STDOUT.

### `IRC::Client::Plugin::PingPong`

    plugins-essential => [IRC::Client::Plugin::PingPong.new]

This plugin responds to server's `PING` requests and is automatically
included in the `plugins-essential` by default.

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
