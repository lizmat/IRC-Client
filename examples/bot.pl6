use lib 'lib';
use IRC::Client;
use IRC::Client::Plugin;

class MyPlug does IRC::Client::Plugin {
    method irc-privmsg-channel ($msg) {
        return $.IRC_NOT_HANDLED unless $msg.text ~~ /^'say' \s+ $<cmd>=(.+)/;
        $msg.reply: "How about: $<cmd>.uc()";
    }
}

my $irc = IRC::Client.new(
    :nick('IRCBot' ~ now.Int)
    :debug<1>
    # :channels<#zofbot>
    # :host<irc.freenode.net>
    :servers(
        mine     => { :port<5667> },
        inspircd => { :port<6667> },
    )
    :plugins(MyPlug.new)
).run;
