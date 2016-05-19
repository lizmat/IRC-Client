unit class IRC::Client::Plugin::PingPong;
method irc-ping ($irc, $e) { $irc.ssay("PONG {$irc.nick} $e<params>[0]") }
