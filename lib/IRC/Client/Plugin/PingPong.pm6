unit class IRC::Client::Plugin::PingPong:ver<1.002001>;
method irc-ping ($irc, $msg) { $irc.ssay("PONG {$irc.nick} $msg<params>[0]") }
