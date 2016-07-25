unit class IRC::Client;

use IRC::Client::Grammar;
use IRC::Client::Grammar::Actions;

my class IRC_FLAG_NEXT {};

role IRC::Client::Plugin is export {
    my IRC_FLAG_NEXT $.NEXT;
    has $.irc is rw;
}

has Str:D  $.host                        = 'localhost';
has Int:D  $.debug                       = 0;
has Str    $.password;
has Int:D  $.port where 0 <= $_ <= 65535 = 6667;
has Str:D  $.nick is rw                  = 'Perl6IRC';
has Str:D  $.username                    = 'Perl6IRC';
has Str:D  $.userhost                    = 'localhost';
has Str:D  $.userreal                    = 'Perl6 IRC Client';
has Str:D  @.channels                    = ['#perl6'];
has        @.filters where .all ~~ Callable;
has        @.plugins;
has        %.servers;
has Bool   $!is-connected                = False;
has Lock   $!lock                        = Lock.new;
has Channel $!event-pipe                 = Channel.new;

my &colored = try {
    require Terminal::ANSIColor;
    &colored
    = GLOBAL::Terminal::ANSIColor::EXPORT::DEFAULT::<&colored>;
} // sub (Str $s, $) { $s };

method run {
    self!prep-servers;
    .irc = self for @.plugins.grep: { .DEFINITE and .^can: 'irc' };

    start {
        my $closed = $!event-pipe.closed;
        loop {
            if $!event-pipe.receive -> $e {
                $!debug and debug-print $e, :in, :server($e.server);
                $!lock.protect: {
                    self!handle-event: $e;
                    CATCH { default { warn $_; warn .backtrace } }
                };
            }
            elsif $closed { last }
        }
    }

    for %!servers.kv -> $s-name, $s-conf {
        $s-conf<promise>
        = IO::Socket::Async.connect($s-conf<host>, $s-conf<port>).then: {
            $!lock.protect: { $s-conf<sock> = .result; };

            self!ssay: "PASS $!password", :server($s-name)
                if $!password.defined;
            self!ssay: "NICK $!nick", :server($s-name);
            self!ssay:
                "USER $!username $!username $!host :$!userreal",
                :server($s-name);

            my $left-overs = '';
            react {
                whenever $s-conf<sock>.Supply :bin -> $buf is copy {
                    my $str = try $buf.decode: 'utf8';
                    $str or $str = $buf.decode: 'latin-1';
                    $str = ($left-overs//'') ~ $str;

                    (my $events, $left-overs)
                    = self!parse: $str, :server($s-name);
                    $!event-pipe.send: $_ for $events.grep: *.defined;
                }
                CATCH { default { warn $_; warn .backtrace } }
            }
            $s-conf<sock>.close;
            CATCH { default { warn $_; warn .backtrace } }
        };
    }
    await Promise.allof: %!servers.values».<promise>;
}

method emit-custom (|c) {
    $!event-pipe.send: c;
}

method send (:$where!, :$text!, :$server, :$notice) {
    for $server || |%!servers.keys.sort {
        self.send-cmd: $notice ?? 'NOTICE' !! 'PRIVMSG', $where, $text,
            :server($_);
    }
}

method send-cmd ($cmd, *@args is copy, :$server) {
    CATCH { default { warn $_; warn .backtrace } }

    say "About to check filter stuff `{@!filters}`";
    if $cmd eq 'NOTICE'|'PRIVMSG' and @!filters
        and my @f = @!filters.grep({
            .signature.ACCEPTS: \(@args[0], where => @args[1])
        })
    {
        say "Starting filtering: `@args[]`";
        start {
            CATCH { default { warn $_; warn .backtrace } }

            my ($where, $text) = @args;
            for @f -> $f {
                given $f.signature.params.elems {
                    when 1 { $text = $f($text); }
                    when 2 { ($text, $where) = $f($text, :$where) }
                }
            }
            self!ssay: :$server, join ' ', $cmd, $where, ":$text";
        }
    }
    else {
        @args[*-1] = ':' ~ @args[*-1];
        self!ssay: :$server, join ' ', $cmd, @args;
    }
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
            self!ssay: "JOIN $_", :server($e.server) for @.channels;
        }
        when 'PING' { return $e.reply; }
        when 'JOIN' {
            # say "Joined channel $e.channel() on $e.server()"
                # if $e.nick eq %!servers{ $e.server }<nick>;
        }
    }

    my $event-name = 'irc-' ~ $e.^name.subst('IRC::Client::Message::', '')
        .lc.subst: '::', '-', :g;

    my @events = flat gather {
        given $event-name {
            when 'irc-privmsg-channel' | 'irc-notice-channel' {
                my $nick = $!nick;
                if $e.text.subst-mutate: /^ $nick <[,:\s]> \s* /, '' {
                    take 'irc-addressed', ('irc-to-me' if $!is-connected);
                }
                elsif $e ~~ / << $nick >> / and $!is-connected {
                    take 'irc-mentioned';
                }
                take $event-name, $event-name eq 'irc-privmsg-channel'
                        ?? 'irc-privmsg' !! 'irc-notice';
            }
            when 'irc-privmsg-me' {
                take $event-name, ('irc-to-me' if $!is-connected),
                    'irc-privmsg';
            }
            when 'irc-notice-me' {
                take $event-name, ('irc-to-me' if $!is-connected),
                    'irc-notice';
            }
            when 'irc-mode-channel' | 'irc-mode-me' {
                take $event-name, 'irc-mode';
            }
            when 'irc-numeric' {
                if $e.command eq '001' {
                    $!is-connected = True ;
                    take 'irc-connected';
                }
                take 'irc-' ~ $e.command, $event-name;
            }
        }
        take 'irc-all';
    }

    EVENT: for @events -> $event {
        debug-print "emitting `$event`", :sys
            if $!debug >= 3 or ($!debug == 2 and not $event eq 'irc-all');

        for self!plugs-that-can($event, $e) {
            my $res = ."$event"($e);
            next if $res ~~ IRC_FLAG_NEXT;
            if $res ~~ Promise {
                $res.then: { $e.reply: $^r unless $^r ~~ Nil or $e.replied; }
            } else {
                $e.reply: $res unless $res ~~ Nil or $e.replied;
            }
            last EVENT;

            CATCH { default { warn $_, .backtrace; } }
        }
    }
}

method !plugs-that-can ($method, $e) {
    gather {
        for @!plugins -> $plug {
            take $plug if .cando: \($plug, $e)
                for $plug.^can: $method;
        }
    }
}

method !ssay (Str:D $msg, :$server = '*') {
    $!debug and debug-print $msg, :out, :$server;
    %!servers{ $server }<sock>.print("$msg\n");
    self;
}

method !parse (Str:D $str, :$server) {
    return |IRC::Client::Grammar.parse(
        $str,
        :actions( IRC::Client::Grammar::Actions.new: :irc(self), :$server )
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
