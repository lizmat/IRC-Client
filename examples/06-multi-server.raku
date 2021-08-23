use IRC::Client;

class BFF {
    method irc-to-me ($ where /'♥'/) { 'I ♥ YOU!' }
}

.run with IRC::Client.new:
    :debug
    :plugins(BFF)
    :nick<MahBot>
    :channels<#raku>
    :servers(
        libera => %(
            :host<irc.libera.chat>,
        ),
        local => %(
            :nick<RakuBot>,
            :channels<#lizbot #raku>,
            :host<localhost>,
        )
    )
