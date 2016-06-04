use v6;
use lib 'lib';
use IRC::Client;

my $irc = IRC::Client.new(
    :nick('IRCBot' ~ now.Int)
    :debug
    :port<5667>
).run;
