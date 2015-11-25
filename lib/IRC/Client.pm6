use v6;
class IRC::Client::Plugin { ... }
class IRC::Client:ver<1.001001> {

    has Str $.host                          = 'localhost';
    has Int $.port where 0 <= $_ <= 65535   = 6667;
    has Str $.nick where 1 <= .chars <= 9   = 'Perl6IRC';
    has Str $.username                      = 'Perl6IRC';
    has Str $.userhost                      = 'localhost';
    has Str $.userreal                      = 'Perl6 IRC Client';
    has Str @.channels                      = ['#perl6bot'];
    has IO::Socket::Async   $.sock;
    has IRC::Client::Plugin @.plugins       = [];

    method run {
        await IO::Socket::Async.connect( $!host, $!port ).then({
            $!sock = .result;
            $.ssay("NICK $!nick\n");
            $.ssay("USER $!username $!userhost $!host :$!userreal\n");
            $.ssay("JOIN $_\n") for @!channels;

            Supply.interval( .interval ).tap({ $OUTER::_.interval(self) })
                for @!plugins.grep(*.interval);

            react {
                whenever $!sock.chars-supply -> $str is copy {
                    $str.say;
                    .msg(self, $str) for @!plugins.grep(so *.msg);
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
}
