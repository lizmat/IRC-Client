use IRC::Client;
.run with IRC::Client.new:
    :nick<MahBot>
    :host(%*ENV<IRC_CLIENT_HOST> // 'irc.libera.chat')
    :channels<#raku>
    :debug
    :plugins(class { method irc-to-me ($_) { .text.uc } })
