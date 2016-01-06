unit class IRC::Client::Plugin::PingPong:ver<2.003001>;
method irc-ping ($irc, $e) { $irc.ssay("PONG {$irc.nick} $e<params>[0]") }
