use lib <lib>;
use IRC::Client;
.run with IRC::Client.new:
    :nick<MahBot>
    :host<irc.freenode.net>
    :channels<#zofbot>
    :debug
    :plugins(class { method irc-to-me ($_) { .text.uc } })
