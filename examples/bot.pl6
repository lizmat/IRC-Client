use v6;
use lib 'lib';
use IRC::Client::Grammar;
use IRC::Client::Grammar:Actions;

say IRC::Client::Grammar.parse(
    'PRIVMSG #perl6 :hello',
    actions => IRC::Client::Grammar::Actions.new,
).made;

# use IRC::Client;
#
# my $irc = IRC::Client.new(
#     :debug
#     :port<5667>
# ).run;
