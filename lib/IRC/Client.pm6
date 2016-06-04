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
            CATCH { warn .backtrace }

            whenever $!sock.Supply :bin -> $buf is copy {
                my $str = try $buf.decode: 'utf8';
                $str or $str = $buf.decode: 'latin-1';
                $str ~= $left-overs;

                (my $events, $left-overs) = self!parse: $str;
                $str ~~ /$<left>=(\N*)$/;
                dd $str;
                say "#### SHOULD Left over: `$<left>`";
                say "#### LEFT OVERS: `$left-overs`";
                for $events.grep: *.defined -> $e {
                    CATCH { warn .backtrace }
                    $!debug and debug-print $e, 'in';
                    self!handle-event: $e;
                }
            }
        }
        $!sock.close;
    });
}

method send-cmd ($cmd, *@args) {
    @args[*-1] = ':' ~ @args[*-1];
    self!ssay: join ' ', $cmd, @args;
}

method !handle-event ($e) {
    given $e.command {
        when '001'  { self!ssay: "JOIN @.channels[]"; }
        when 'PING' { $e.reply }
        when 'JOIN' {
            say "Joined channel $e.channel()";
        }
    }
}

method !ssay (Str:D $msg) {
    $!debug and debug-print $msg, 'out';
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

sub debug-print (Str(Any) $str, $dir where * eq 'in' | 'out') {
    state $colored = try {
        require Terminal::ANSIColor;
        $colored = GLOBAL::Terminal::ANSIColor::EXPORT::DEFAULT::<&colored>;
    } // sub (Str $s) { '' };

    my @out;
    if $str ~~ /^ '❚⚠❚'/ {
        @out = $str.split: ' ', 3;
        @out[0] = $colored(@out[0], 'bold white on_red');
        @out[1] = @out[1] ~~ /^ <[0..9]>**3 $/
            ?? $colored(@out[1], 'bold red')
            !! $colored(@out[1], 'bold magenta');
        @out[2] = $colored(@out[2], 'bold cyan');
    }
    else {
        @out = $str.split: ' ', 2;
        @out[0] = @out[0] ~~ /^ <[0..9]>**3 $/
            ?? $colored(@out[0], 'bold red')
            !! $colored(@out[0], 'bold magenta');
        @out[1] = $colored(@out[1], 'bold cyan');
    }

    put ( $dir eq 'in'
        ?? $colored('▬▬▶ ', 'bold blue' )
        !! $colored('◀▬▬ ', 'bold green')
    ) ~ @out.join: ' ';
}
