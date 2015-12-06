use IRC::Grammar;
use IRC::Grammar::Actions;
unit class IRC::Parser:ver<1.001001>;

sub parse-irc (Str:D $input) is export {
    IRC::Grammar.parse($input, actions => IRC::Grammar::Actions).made // [];
}
