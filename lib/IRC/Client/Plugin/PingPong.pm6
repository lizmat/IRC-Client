unit class IRC::Client::Plugin::PingPong:ver<1.002001>;
method irc-ping ($irc, $e) { $irc.ssay("PONG {$irc.nick} $e<params>[0]") }
