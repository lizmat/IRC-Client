use v6;
use IRC::Parser; # parse-irc
use IRC::Client::Plugin::PingPong;
use IRC::Client::Plugin;
class IRC::Client:ver<1.002001> {
    has Bool:D $.debug                          = False;
    has Str:D  $.host                           = 'localhost';
    has Int:D  $.port where 0 <= $_ <= 65535    = 6667;
    has Str:D  $.nick                           = 'Perl6IRC';
    has Str:D  $.username                       = 'Perl6IRC';
    has Str:D  $.userhost                       = 'localhost';
    has Str:D  $.userreal                       = 'Perl6 IRC Client';
    has Str:D  @.channels                       = ['#perl6bot'];
    has IO::Socket::Async   $.sock;
    has @.plugins           = [];
    has @.plugins-essential = [
        IRC::Client::Plugin::PingPong.new
    ];
    has @!plugs             = [|@!plugins-essential, |@!plugins];

    method run {
        await IO::Socket::Async.connect( $!host, $!port ).then({
            $!sock = .result;
            $.ssay("NICK $!nick\n");
            $.ssay("USER $!username $!userhost $!host :$!userreal\n");
            $.ssay("JOIN $_\n") for @!channels;

            .register: self for @!plugs.grep(*.^can: 'register');

            react {
                whenever $!sock.Supply -> $str is copy {
                    $!debug and "[server {DateTime.now}] {$str}".put;
                    my $messages = parse-irc $str;
                    MESSAGES: for @$messages -> $message {
                        $message<handled> = False;
                        $message<pipe>    = {};

                        if ( $message<command> eq 'PRIVMSG'
                            and $message<params>[0] eq $!nick
                        ) {
                            for @!plugs.grep(*.^can: 'privmsg-me') -> $p {
                                my $res = $p.privmsg-me(self, $message);
                                next MESSAGES unless $res === irc-not-handled;
                            }
                        }

                        if ( $message<command> eq 'NOTICE'
                            and $message<params>[0] eq $!nick
                        ) {
                            for @!plugs.grep(*.^can: 'notice-me') -> $p {
                                my $res = $p.notice-me(self, $message);
                                next MESSAGES unless $res === irc-not-handled;
                            }
                        }

                        my $cmd = 'irc-' ~ $message<command>.lc;
                        for @!plugs.grep(*.^can: $cmd) -> $p {
                            my $res = $p."$cmd"(self, $message);
                            next MESSAGES unless $res === irc-not-handled;
                        }

                        for @!plugs.grep(*.^can: 'msg') -> $p {
                            my $res = $p.msg(self, $message);
                            next MESSAGES unless $res === irc-not-handled;
                        }
                    }
                }
            }

            say "Closing connection";
            $!sock.close;
        });
    }

    method ssay (Str:D $msg) {
        $!debug and "{plug-name}$msg".put;
        $!sock.print("$msg\n");
        self;
    }

    method privmsg (Str $who, Str $what) {
        my $msg = ":$!nick!$!username\@$!userhost PRIVMSG $who :$what\n";
        $!debug and "{plug-name}$msg".put;
        $!sock.print("$msg\n");
        self;
    }
}

sub plug-name {
    my $plug = callframe(3).file;
    my $cur = $?FILE;
    return '[core] ' if $plug eq $cur;
    $cur ~~ s/'.pm6'$//;
    $plug ~~ s:g/^ $cur '/' | '.pm6'$//;
    $plug ~~ s/'/'/::/;
    return "[$plug] ";
}