use v6;
use IRC::Client;
use IRC::Client::Plugin;
unit class IRC::Client::Plugin::HNY:ver<1.001001> does IRC::Client::Plugin;
multi method interval (                ) {  6  }
multi method interval (IRC::Client $irc) {
    $irc.privmsg(
        $irc.channels[0], "5 seconds passed. Time is now " ~ now
    );
}
