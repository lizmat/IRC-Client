use lib <lib>;

use IRC::Client;
class Trickster {
    multi method irc-to-me ($ where /time/) { DateTime.now }
    multi method irc-to-me ($ where /temp \s+ $<temp>=\d+ $<unit>=[F|C]/) {
        $<unit> eq 'F' ?? "That's {($<temp> - 32) × .5556}°C"
                       !! "That's { $<temp> × 1.8 + 32   }°F"
    }
}

class BFF { method irc-to-me ($ where /'♥'/) { 'I ♥ YOU!' } }

.run with IRC::Client.new:
    :nick<MahBot>
    :alias('foo', /b.r/)
    :host(%*ENV<IRC_CLIENT_HOST> // 'irc.freenode.net')
    :channels<#zofbot>
    :debug
    :plugins(Trickster, BFF)
