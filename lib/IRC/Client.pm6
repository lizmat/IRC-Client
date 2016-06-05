unit class IRC::Client;

use IRC::Client::Grammar;
use IRC::Client::Grammar::Actions;

has Str:D  $.host                        = 'localhost';
has Int:D  $.debug                       = 0;
has Str    $.password;
has Int:D  $.port where 0 <= $_ <= 65535 = 6667;
has Str:D  $.nick is rw                  = 'Perl6IRC';
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

        react {
            CATCH { warn .backtrace }

            whenever $!sock.Supply :bin -> $buf is copy {
                state $left-overs = '';
                my $str = try $buf.decode: 'utf8';
                $str or $str = $buf.decode: 'latin-1';
                $str = $left-overs ~ $str;

                (my $events, $left-overs) = self!parse: $str;
                $str ~~ /$<left>=(\N*)$/;
                for $events.grep: *.defined -> $e {
                    CATCH { warn .backtrace }
                    $!debug and debug-print $e, :in;
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
            say "Joined channel $e.channel()"
                if $e.nick eq $!nick;
        }
    }

    my $method = 'irc-' ~ $e.^name.subst('IRC::Client::Message::', '')
        .lc.subst: '::', '-', :g;
    $!debug >= 2 and debug-print "emitting `$method`", :sys;
    for self!plugs-that-can: $method {
        last if ."$method"($e).^name eq 'IRC_FLAG_HANDLED';
    }
}

method !plugs-that-can ($method) {
    return @!plugins.grep(*.^can: $method);
}

method !ssay (Str:D $msg) {
    $!debug and debug-print $msg, :out;
    $!sock.print("$msg\n");
    self;
}

method !parse (Str:D $str) {
    return |IRC::Client::Grammar.parse(
        $str,
        actions => IRC::Client::Grammar::Actions.new(
            irc    => self,
            server => 'dummy',
        ),
    ).made;
}

sub debug-print (Str(Any) $str, :$in, :$out, :$sys) {
    state &colored = try {
        require Terminal::ANSIColor;
        &colored
        = GLOBAL::Terminal::ANSIColor::EXPORT::DEFAULT::<&colored>;
    } // sub (Str $s) { '' };

    my @bits = $str.split: ' ';
    if $in {
        my ($pref, $cmd) = 0, 1;
        if @bits[0] eq '❚⚠❚' {
            @bits[0] = colored @bits[0], 'bold white on_red';
            $pref++; $cmd++;
        }
        @bits[$pref] = colored @bits[$pref], 'bold magenta';
        @bits[$cmd] = @bits[$cmd] ~~ /^ <[0..9]>**3 $/
            ?? colored(@bits[$cmd], 'bold red')
            !! colored(@bits[$cmd], 'bold yellow');
        put colored('▬▬▶ ', 'bold blue' ) ~ @bits.join: ' ';
    }
    elsif $out {
        @bits[0] = colored @bits[0], 'bold magenta';
        put colored('◀▬▬ ', 'bold green') ~ @bits.join: ' ';
    }
    elsif $sys {
        put colored(' ' x 4 ~ '↳', 'bold white') ~ ' '
            ~ @bits.join(' ')
                .subst: /(\`<-[`]>+\`)/, { colored(~$0, 'bold cyan') };
    }
    else {
        die "Unknown debug print mode";
    }
}
