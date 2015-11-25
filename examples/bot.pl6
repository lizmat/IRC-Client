use v6;
use lib 'lib';
use IRC::Client;
use IRC::Client::Plugin::HNY;
say "42";
my $irc = IRC::Client.new(
    :host('irc.freenode.net'),
    plugins => [
        IRC::Client::Plugin::HNY.new,
    ]
).run;
