unit class IRC::Client;

use IRC::Client::Grammar;
use IRC::Client::Grammar::Actions;

has Str:D  $.host                        = 'localhost';
has Bool   $.debug                       = False;
has Str    $.password;
has Int:D  $.port where 0 <= $_ <= 65535 = 6667;
has Str:D  $.nick                        = 'Perl6IRC';
has Str:D  $.username                    = 'Perl6IRC';
has Str:D  $.userhost                    = 'localhost';
has Str:D  $.userreal                    = 'Perl6 IRC Client';
has Str:D  @.channels                    = ['#perl6'];
has        @.plugins;
has        @.servers;
has IO::Socket::Async   $!sock;

method run {
    await IO::Socket::Async.connect( $!host, $!port ).then({
        $!sock = .result;
        self!ssay: "PASS $!password" if $!password.defined;
        self!ssay: "NICK $!nick";
        self!ssay: "USER $!username $!username $!host :$!userreal";

        my $left-overs = '';
        react {
            whenever $!sock.Supply :bin -> $buf is copy {
                my $str = try $buf.decode: 'utf8';
                $str or $str = $buf.decode: 'latin-1';
                $str ~= $left-overs;

                (my $events, $left-overs) = self!parse: $str;
                for $events.grep: *.defined -> $e {
                    $!debug and debug-print $e;
                    CATCH { warn .backtrace }
                }
            }

            CATCH { warn .backtrace }
        }
        $!sock.close;
    });
}

method !ssay (Str:D $msg) {
    $!debug and debug-print $msg;
    $!sock.print("$msg\n");
    self;
}

method !parse (Str:D $str) {
    return IRC::Client::Grammar.parse(
        $str,
        actions => IRC::Client::Grammar::Actions.new(
            irc    => self,
            server => 'dummy',
        ),
    ).made;
}

sub debug-print ($str, $dir where * eq 'in' | 'out') {
    state $color = try {
        require Terminal::ANSIColor;
        $color = GLOBAL::Terminal::ANSIColor::EXPORT::DEFAULT::<&color>;
    } // sub (Str $s) { '' };

    put ( $dir eq 'in'
        ?? $color('bold blue' ) ~ '▬▬▬▶ '
        !! $color('bold green') ~ '◀▬▬▬ '
    ) ~ $color('bold red') ~ join $color('reset'), $str.split: ' ', 2;
}
