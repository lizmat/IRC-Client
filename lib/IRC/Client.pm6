use v6;
use IRC::Parser; # parse-irc
use IRC::Client::Plugin::PingPong;
role IRC::Client::Plugin { ... }
class IRC::Client:ver<1.001001> {
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

    method run {
        await IO::Socket::Async.connect( $!host, $!port ).then({
            $!sock = .result;
            $.ssay("NICK $!nick\n");
            $.ssay("USER $!username $!userhost $!host :$!userreal\n");
            $.ssay("JOIN $_\n") for @!channels;

            Supply.interval( .interval ).tap({ $OUTER::_.interval(self) })
                for @!plugins.grep(*.interval);

            react {
                whenever $!sock.Supply -> $str is copy {
                    $!debug and $str.say;
                    my $messages = parse-irc $str;
                    for @$messages -> $message {
                        .msg(self, $message)
                        for (@!plugins-essential, @!plugins).flat.grep(*.msg);
                    }
                }
            }

            say "Closing connection";
            $!sock.close;
        });
    }

    method ssay (Str:D $msg) {
        $!sock.print("$msg\n");
        self;
    }

    method privmsg (Str $who, Str $what) {
        my $msg = ":$!nick!$!username\@$!userhost PRIVMSG $who :$what\n";
        $!debug and say ".privmsg({$msg.subst("\n", "␤", :g)})";
        self.ssay: $msg;
        self;
    }
}
