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
        .irc-start-up: self for @!plugs.grep(*.^can: 'irc-start-up');

        await IO::Socket::Async.connect( $!host, $!port ).then({
            $!sock = .result;
            $.ssay("NICK $!nick\n");
            $.ssay("USER $!username $!userhost $!host :$!userreal\n");
            $.ssay("JOIN $_\n") for @!channels;

            .irc-connected: self for @!plugs.grep(*.^can: 'irc-connected');

            react {
                whenever $!sock.Supply -> $str is copy {
                    $!debug and "[server {DateTime.now}] {$str}".put;
                    my $events = parse-irc $str;
                    EVENTS: for @$events -> $e {
                        $e<pipe>    = {};

                        for @!plugs.grep(*.^can: 'irc-all-events') -> $p {
                            my $res = $p.irc-all-events(self, $e);
                            next EVENTS unless $res === IRC_NOT_HANDLED;
                        }

                        if ( $e<command> eq 'PRIVMSG'
                            and $e<params>[0] eq $!nick
                        ) {
                            for @!plugs.grep(*.^can: 'irc-privmsg-me') -> $p {
                                my $res = $p.irc-privmsg-me(self, $e);
                                next EVENTS unless $res === IRC_NOT_HANDLED;
                            }
                        }

                        if ( $e<command> eq 'NOTICE'
                            and $e<params>[0] eq $!nick
                        ) {
                            for @!plugs.grep(*.^can: 'irc-notice-me') -> $p {
                                my $res = $p.irc-notice-me(self, $e);
                                next EVENTS unless $res === IRC_NOT_HANDLED;
                            }
                        }

                        my $cmd = 'irc-' ~ $e<command>.lc;
                        for @!plugs.grep(*.^can: $cmd) -> $p {
                            my $res = $p."$cmd"(self, $e);
                            next EVENTS unless $res === IRC_NOT_HANDLED;
                        }

                        for @!plugs.grep(*.^can: 'irc-unhandled') -> $p {
                            my $res = $p.irc-unhandled(self, $e);
                            next EVENTS unless $res === IRC_NOT_HANDLED;
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
