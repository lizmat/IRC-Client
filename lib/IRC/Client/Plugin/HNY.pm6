use v6;
use JSON::Tiny;
use IRC::Client;
use IRC::Client::Plugin;

unit class IRC::Client::Plugin::HNY:ver<1.001001> does IRC::Client::Plugin;


get_UTC_offsets();

multi method interval (                ) {  6  }
multi method interval (IRC::Client $irc) {
    $irc.privmsg(
        $irc.channels[0], "5 seconds passed. Time is now " ~ now
    );
}



sub get_UTC_offsets {
    my $times = from-json 'tzs.json'.IO.slurp;

    for $times -> $zone {
        say "Offset is $zone<offset>";
    }
}
