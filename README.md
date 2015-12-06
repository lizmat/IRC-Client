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
The Artistic License 2.0. See the C<LICENSE> file included in this
distribution for complete details.
