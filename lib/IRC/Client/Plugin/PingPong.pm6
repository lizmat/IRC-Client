use v6;
unit class IRC::Client::Plugin::PingPong:ver<1.001001>;

multi method msg () { True }
multi method msg ($irc, $msg) {
    return unless $msg<command> eq 'PING';
    my $res = "PONG {$irc.nick} $msg<params>[0]";
    $irc.debug and say $res;
    $irc.ssay($res);
}
