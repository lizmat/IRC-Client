use IRC::Grammar;
use IRC::Grammar::Actions;
unit class IRC::Parser;

sub parse-irc (Str:D $input) is export {
    IRC::Grammar.parse($input, actions => IRC::Grammar::Actions).made // [];
}
