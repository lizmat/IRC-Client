use v6;
use lib 'lib';
use IRC::Client;
use IRC::Client::Plugin::Debugger;

my $irc = IRC::Client.new(
    :host('localhost'),
    :debug,
    plugins => [
        IRC::Client::Plugin::Debugger.new
    ]
).run;
