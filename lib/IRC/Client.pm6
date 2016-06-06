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
has        %.servers;

my &colored = try {
    require Terminal::ANSIColor;
    &colored
    = GLOBAL::Terminal::ANSIColor::EXPORT::DEFAULT::<&colored>;
} // sub (Str $s, $) { $s };

method run {
    self!prep-servers;

    my $lock = Lock.new;
    for %!servers.kv -> $s-name, $s-conf {
        $s-conf<promise>
        = IO::Socket::Async.connect($s-conf<host>, $s-conf<port>).then: {
            $lock.protect: { $s-conf<sock> = .result; };

            self!ssay: "PASS $!password", :server($s-name)
                if $!password.defined;
            self!ssay: "NICK $!nick", :server($s-name);
            self!ssay:
                "USER $!username $!username $!host :$!userreal",
                :server($s-name);

            my $left-overs = '';
            react {
                CATCH { warn .backtrace }

                whenever $s-conf<sock>.Supply :bin -> $buf is copy {
                    my $str = try $buf.decode: 'utf8';
                    $str or $str = $buf.decode: 'latin-1';
                    $str = ($left-overs//'') ~ $str;

                    (my $events, $left-overs)
                    = self!parse: $str, :server($s-name);
                    for $events.grep: *.defined -> $e {
                        $!debug and debug-print $e, :in, :server($e.server);
                        $lock.protect: { self!handle-event: $e; };
                    }
                }
            }
            $s-conf<sock>.close;
        };
    }
    await Promise.allof: %!servers.values».<promise>;
}

method send-cmd ($cmd, *@args, :$server) {
    @args[*-1] = ':' ~ @args[*-1];
    self!ssay: :$server, join ' ', $cmd, @args;
}

method !prep-servers {
    %!servers = '*' => {} unless %!servers;

    for %!servers.values -> $s {
        $s{$_} //= self."$_"()
            for <host password port nick username userhost userreal>;
        $s<channels> = @.channels;
        $s<socket> = Nil;
    }
}

method !handle-event ($e) {
    given $e.command {
        when '001'  {
            %!servers{ $e.server }<nick> = $e.args[0];
            self!ssay: "JOIN @.channels[]", :server($e.server);
        }
        when 'PING' { $e.reply }
        when 'JOIN' {
            # say "Joined channel $e.channel() on $e.server()"
                # if $e.nick eq %!servers{ $e.server }<nick>;
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

method !ssay (Str:D $msg, :$server = '*') {
    $!debug and debug-print $msg, :out, :$server;
    %!servers{ $server }<sock>.print("$msg\n");
    self;
}

method !parse (Str:D $str, :$server) {
    return |IRC::Client::Grammar.parse(
        $str,
        actions => IRC::Client::Grammar::Actions.new(
            irc    => self,
            server => $server,
        ),
    ).made;
}

sub debug-print (Str(Any) $str, :$in, :$out, :$sys, :$server) {
    my $server-str = $server
        ?? colored($server, 'bold white on_cyan') ~ ' ' !! '';

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
        put colored('▬▬▶ ', 'bold blue' ) ~ $server-str ~ @bits.join: ' ';
    }
    elsif $out {
        @bits[0] = colored @bits[0], 'bold magenta';
        put colored('◀▬▬ ', 'bold green') ~ $server-str ~ @bits.join: ' ';
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
