use lib <lib>;

use IRC::Client;
use Pastebin::Shadowcat;
use Mojo::UserAgent:from<Perl5>;

class Bash {
    constant $BASH_URL = 'http://bash.org/?random1';
    constant $cache    = Channel.new;
    has        $!ua    = Mojo::UserAgent.new;

    multi method irc-to-me ($ where /bash/) {
        start $cache.poll or do { self!fetch-quotes; $cache.poll };
    }

    method !fetch-quotes {
        $cache.send: $_
            for $!ua.get($BASH_URL).res.dom.find('.qt').each».all_text;
    }
}

.run with IRC::Client.new:
    :nick<MahBot>
    :host(%*ENV<IRC_CLIENT_HOST> // 'irc.freenode.net')
    :channels<#zofbot>
    :debug
    :plugins(Bash.new)
    :filters(
        -> $text where .lines > 1 || .chars > 300 {
            Pastebin::Shadowcat.new.paste: $text.lines.join: "\n";
        }
    )
