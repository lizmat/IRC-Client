use lib <lib>;

use IRC::Client;
use Pastebin::Shadowcat;
use Mojo::UserAgent:from<Perl5>;

class Bash {
    has      @!quotes;
    has      $!ua      = Mojo::UserAgent.new;
    constant $BASH_URL = 'http://bash.org/?random1';

    method irc-to-me ($ where /bash/) {
        start self!fetch-quotes and @!quotes.shift;
    }
    method !fetch-quotes {
        @!quotes ||= $!ua.get($BASH_URL).res.dom.find('.qt').each».all_text;
    }
}

.run with IRC::Client.new:
    :nick<MahBot>
    :host<localhost>
    :channels<#zofbot>
    :debug
    :plugins(Bash.new)
    :filters(
        -> $text where .lines > 1 || .chars > 300 {
            Pastebin::Shadowcat.new.paste: $text.lines.join: "\n";
        }
    )
