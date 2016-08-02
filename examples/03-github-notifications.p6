use lib <lib>;

use IRC::Client;
use HTTP::Tinyish;
use JSON::Fast;

class GitHub::Notifications does IRC::Client::Plugin {
    has Str:D $.token  = %*ENV<GITHUB_TOKEN>;
    has       $!ua     = HTTP::Tinyish.new;
    constant  $API_URL = 'https://api.github.com/notifications';

    method irc-connected ($) {
        start react {
            whenever self!notification.grep(* > 0) -> $num {
                $.irc.send: :where<Zoffix>
                            :text("You have $num unread notifications!")
                            :notice;
            }
        }
    }

    method !notification {
        supply {
            loop {
                my $res = $!ua.get: $API_URL, :headers{ :Authorization("token $!token") };
                $res<success> and emit +grep *.<unread>, |from-json $res<content>;
                sleep $res<headers><X-Poll-Interval> || 60;
            }
        }
    }
}

.run with IRC::Client.new:
    :nick<MahBot>
    :host(%*ENV<IRC_CLIENT_HOST> // 'irc.freenode.net')
    :channels<#zofbot>
    :debug
    :plugins(GitHub::Notifications.new)
