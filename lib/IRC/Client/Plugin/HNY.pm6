use v6;
use IRC::Client;
use IRC::Client::Plugin;
unit class IRC::Client::Plugin::HNY:ver<1.001001> does IRC::Client::Plugin;
multi method interval (                       ) {  2  }
multi method interval (IRC::Client $irc) {
    $irc.ssay("5 seconds passed. Time is now " ~ now);
}
