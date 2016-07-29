use lib <lib>;

use IRC::Client;

class BFF {
    method irc-to-me ($ where /'♥'/) { 'I ♥ YOU!' }
}

.run with IRC::Client.new:
    :debug
    :plugins(BFF)
    :nick<MahBot>
    :channels<#zofbot>
    :servers(
        freenode => %(
            :host<irc.freenode.net>,
        ),
        local => %(
            :nick<P6Bot>,
            :channels<#zofbot #perl6>,
            :host<localhost>,
        )
    )
