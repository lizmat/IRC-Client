use v6;
use Data::Dump;
unit class IRC::Client::Plugin::Debugger:ver<1.001001>;

multi method msg () { True }
multi method msg ($irc, $msg) {
    say Dump $msg, :indent(4);
}
