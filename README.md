[![Build Status](https://travis-ci.org/zoffixznet/perl6-IRC-Client.svg)](https://travis-ci.org/zoffixznet/perl6-IRC-Client)

# NAME

IRC::Client - Extendable Internet Relay Chat client

# SYNOPSIS

```perl6
    use IRC::Client;
    use Pastebin::Shadowcat;

    .run with IRC::Client.new:
        :host<irc.freenode.net>
        :channels<#perl6bot #zofbot>
        :debug
        :plugins[
            class { method irc-to-me ($ where /hello/) { 'Hello to you too!'} }
        ]
        :filters[
            -> $text where .chars > 200 {
                'The output is too large to show here. See: '
                ~ Pastebin::Shadowcat.new.paste: $text;
            }
        ];
```

# DESCRIPTION

The module provides the means to create clients to communicate with
IRC (Internet Relay Chat) servers. Has support for non-blocking responses
and output post-processing.

# DOCUMENTATION MAP

* [Basics Tutorial](docs/01-basics.md)
* [Event reference](docs/02-event-reference.md)

---

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

The `META6.json` file of this distribution may be distributed and modified
without restrictions or attribution.
