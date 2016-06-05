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

method run {
    self!prep-servers;

    for %!servers.kv -> $s-name, $s-conf {
        %!servers{ $s-name }<promise>
        = IO::Socket::Async.connect( $s-conf<host>, $s-conf<port> ).then({
            $s-conf<sock> = .result;

            self!ssay: "PASS $!password", :server($s-name)
                if $!password.defined;
            self!ssay: "NICK $!nick", :server($s-name);
            self!ssay:
                "USER $!username $!username $!host :$!userreal",
                :server($s-name);

            react {
                CATCH { warn .backtrace }

                whenever $s-conf<sock>.Supply :bin -> $buf is copy {
                    state $left-overs = '';
                    my $str = try $buf.decode: 'utf8';
                    $str or $str = $buf.decode: 'latin-1';
                    $str = $left-overs ~ $str;

                    (my $events, $left-overs)
                    = self!parse: $str, :server($s-name);
                    # say $events, $left-overs;
                    for $events.grep: *.defined -> $e {
                        say $e;
                        CATCH { warn .backtrace }
                        $!debug and debug-print $e, :in;
                        # self!handle-event: $e, $s-name;
                    }
                }
            }
            $s-conf<sock>.close;
        })
    }
    await Promise.allof: %!servers.values».<promise>;
}

method send-cmd ($cmd, *@args) {
    @args[*-1] = ':' ~ @args[*-1];
    self!ssay: join ' ', $cmd, @args;
}

method !prep-servers {
    %!servers = '*' => {} unless %!servers;

    for %!servers.values -> $s {
        $s{$_} //= self."$_"()
            for <host password port nick username userhost userreal>;
        $s<channels> = @.channels;
    }
}

method !handle-event ($e) {
    # given $e.command {
    #     when '001'  { self!ssay: "JOIN @.channels[]", :server($e.server); }
    #     when 'PING' { $e.reply }
    #     when 'JOIN' {
    #         say "Joined channel $e.channel()"
    #             if $e.nick eq $!nick;
    #     }
    # }
    #
    # my $method = 'irc-' ~ $e.^name.subst('IRC::Client::Message::', '')
    #     .lc.subst: '::', '-', :g;
    # $!debug >= 2 and debug-print "emitting `$method`", :sys;
    # for self!plugs-that-can: $method {
    #     last if ."$method"($e).^name eq 'IRC_FLAG_HANDLED';
    # }
}

method !plugs-that-can ($method) {
    return @!plugins.grep(*.^can: $method);
}

method !ssay (Str:D $msg, :$server = '*') {
    return;
    $!debug and debug-print $msg, :out;
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

sub debug-print (Str(Any) $str, :$in, :$out, :$sys) {
    return;
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
