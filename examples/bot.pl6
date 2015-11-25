use v6;
use lib 'lib';
use IRC::Client;
use IRC::Client::Plugin::HNY;

my $irc = IRC::Client.new(
    :host('irc.freenode.net'),
    :debug,
    plugins => [
        IRC::Client::Plugin::HNY.new,
    ]
).run;
