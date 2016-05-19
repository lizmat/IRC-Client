use Data::Dump;
use IRC::Client::Plugin;
unit class IRC::Client::Plugin::Debugger is IRC::Client::Plugin;

method irc-all-events ($irc, $e) {
    say Dump $e, :indent(4);
    return IRC_NOT_HANDLED;
}
