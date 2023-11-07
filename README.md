[![Actions Status](https://github.com/lizmat/IRC-Client/workflows/test/badge.svg)](https://github.com/lizmat/IRC-Client/actions)

NAME
====

IRC::Client - Extendable Internet Relay Chat client

SYNOPSIS
========

```raku
use IRC::Client;
use Pastebin;

.run with IRC::Client.new:
    :host<irc.libera.chat>
    :channels<#rakubot #zofbot>
    :debug
    :plugins(
        class { method irc-to-me ($ where /hello/) { 'Hello to you too!'} }
    )
    :filters(
        -> $text where .chars > 200 {
            'The output is too large to show here. See: '
            ~ Pastebin.new.paste: $text;
        }
    );
```

DESCRIPTION
===========

The module provides the means to create clients to communicate with IRC (Internet Relay Chat) servers. Has support for non-blocking responses and output post-processing.

DOCUMENTATION MAP
=================

* [Blog Post](https://github.com/Raku/CCR/blob/main/Remaster/Zoffix%20Znet/IRC-Client-Raku-Multi-Server-IRC-or-Awesome-Async-Interfaces-with-Raku.md) * [Basics Tutorial](https://github.com/lizmat/IRC-Client/blob/main/docs/01-basics.md) * [Event Reference](https://github.com/lizmat/IRC-Client/blob/main/docs/02-event-reference.md) * [Method Reference](https://github.com/lizmat/IRC-Client/blob/main/docs/03-method-reference.md) * [Big-Picture Behaviour](https://github.com/lizmat/IRC-Client/blob/main/docs/04-big-picture-behaviour.md) * [Examples](https://github.com/lizmat/IRC-Client/blob/main/examples/)

AUTHORS
=======

  * Zoffix Znet (2015-2018)

  * Elizabeth Mattijsen (2021-) <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/IRC-Client . Comments and Pull Requests are welcome.

CONTRIBUTORS
============

  * Daniel Green

  * Patrick Spek

COPYRIGHT AND LICENSE
=====================

Copyright 2015-2021 Zoffix Znet

Copyright 2021-2023 Elizabeth Mattijsen

If you like this module, or what I’m doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

The `META6.json` file of this distribution may be distributed and modified without restrictions or attribution.

