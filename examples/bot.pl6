use v6;
use lib 'lib';
use IRC::Client;
use IRC::Client::Plugin::HNY;
say "42";
my $irc = IRC::Client.new(
    :host('10.10.11.12'),
    plugins => [
        IRC::Client::Plugin::HNY.new,
    ]
).run;
