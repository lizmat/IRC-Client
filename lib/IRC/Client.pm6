unit class IRC::Client;

use IRC::Client::Message;
use IRC::Client::Grammar;
use IRC::Client::Server;
use IRC::Client::Grammar::Actions;

my class IRC_FLAG_NEXT {};

role IRC::Client::Plugin is export {
    my IRC_FLAG_NEXT $.NEXT;
    has $.irc is rw;
}

has @.filters where .all ~~ Callable;
has %.servers where .values.all ~~ IRC::Client::Server;
has @.plugins;
has $.debug;
has Lock    $!lock        = Lock.new;
has Channel $!event-pipe  = Channel.new;
has Channel $!socket-pipe = Channel.new;

my &colored = get-colored;
&colored //= sub (Str $s, $) { $s };

sub get-colored {
    my &colored;
    try {
        require Terminal::ANSIColor;
        &colored = GLOBAL::Terminal::ANSIColor::EXPORT::DEFAULT::<&colored>;
    }
    &colored;
}

submethod BUILD (
    Int:D   :$!debug = 0,
            :$filters = (),
            :$plugins = (),
            :$servers = {},
    Int:D   :$port      where 0 <= $_ <= 65535   = 6667,
    Str     :$password,
    Str:D   :$host      = 'localhost',
            :$nick      = ['P6Bot'],
            :$alias     = [],
    Str:D   :$username  = 'Perl6IRC',
    Str:D   :$userhost  = 'localhost',
    Str:D   :$userreal  = 'Perl6 IRC Client',
            :$channels  = ('#perl6',),
) {
    @!filters = @$filters;
    @!plugins = @$plugins;
    my %servers = %$servers;

    my %all-conf = :$port,     :$password, :$host,     :$nick,     :$alias,
                   :$username, :$userhost, :$userreal, :$channels;

    %servers = '_' => {} unless %servers;
    for %servers.keys -> $label {
        my $conf = %servers{$label};
        my $s = IRC::Client::Server.new(
            :socket(Nil),
            :$label,
            :channels( @($conf<channels> // %all-conf<channels>) ),
            :nick[ |($conf<nick> // %all-conf<nick>) ],
            :alias[ |($conf<alias> // %all-conf<alias>) ],
            |%(
                <host password port username userhost userreal>
                    .map: { $_ => $conf{$_} // %all-conf{$_} }
            ),
        );
        # Automatically add nick__ variants if given just one nick
        $s.nick[1..3] = "$s.nick()[0]_", "$s.nick()[0]__", "$s.nick()[0]___"
            if $s.nick.elems == 1;
        $s.current-nick = $s.nick[0];
        %!servers{$label} = $s;
    }
}

method join (*@channels, :$server) {
    self.send-cmd: 'JOIN', ($_ ~~ Pair ?? .kv !! .Str), :$server
        for @channels;
    self;
}

method nick (*@nicks, :$server = '*') {
    @nicks[1..3] = "@nicks[0]_", "@nicks[0]__", "@nicks[0]___" if @nicks == 1;
    self!set-server-attr($server, 'nick', @nicks);
    self!set-server-attr($server, 'current-nick', @nicks[0]);
    self.send-cmd: 'NICK', @nicks[0], :$server;
    self;
}

method part (*@channels, :$server) {
    self.send-cmd: 'PART', $_, :$server for @channels;
    self;
}

method quit (:$server = '*') {
    if $server eq '*' { .has-quit = True for %!servers.values;    }
    else              { self!get-server($server).has-quit = True; }
    self.send-cmd: 'QUIT', :$server;
    self;
}

method run {
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
        CATCH { default { warn $_; warn .backtrace } }
    }

    .irc-started for self!plugs-that-can('irc-started');
    self!connect-socket: $_ for %!servers.values;
    loop {
        my $s = $!socket-pipe.receive;
        self!connect-socket: $s unless $s.has-quit;
        unless %!servers.values.grep({!.has-quit}) {
            $!debug and debug-print 'All servers quit by user. Exiting', :sys;
            last;
        }
    }
}

method send (:$where!, :$text!, :$server, :$notice) {
    for $server || |%!servers.keys.sort {
        if self!get-server($server).is-connected {
            self.send-cmd: $notice ?? 'NOTICE' !! 'PRIVMSG', $where, $text,
                :server($_);
        }
        else {
            $!debug and debug-print( :out, :$server,
                '.send() called for an unconnected server. Skipping...'
            );
        }
    }

    self;
}

###############################################################################
###############################################################################
###############################################################################
###############################################################################
###############################################################################
###############################################################################

method !change-nick ($server) {
    my $idx = 0;
    for $server.nick.kv -> $i, $n {
        next unless $n eq $server.current-nick;
        $idx = $i + 1;
        $idx = 0 if $idx == $server.nick.elems;
        last;
    };
    if $idx == 0 {
        Promise.in(10).then: {
            $server.current-nick = $server.nick[$idx];
            self.send-cmd: "NICK $server.current-nick()", :$server;
        }
    }
    else {
        $server.current-nick = $server.nick[$idx];
        self.send-cmd: "NICK $server.current-nick()", :$server;
    }
}

method !connect-socket ($server) {
    $!debug and debug-print 'Attempting to connect to server', :out, :$server;
    IO::Socket::Async.connect($server.host, $server.port).then: sub ($prom) {
        if $prom.status ~~ Broken {
            $server.is-connected = False;
            $!debug and debug-print 'Could not connect', :out, :$server;
            sleep 10;
            $!socket-pipe.send: $server;
            return;
        }

        $server.socket = $prom.result;

        self!ssay: "PASS $server.password()", :$server
            if $server.password.defined;
        self!ssay: "NICK {$server.nick[0]}", :$server;

        self!ssay: :$server, join ' ', 'USER', $server.username,
            $server.username, $server.host, ':' ~ $server.userreal;

        my $left-overs = '';
        react {
            whenever $server.socket.Supply :bin -> $buf is copy {
                my $str = try $buf.decode: 'utf8';
                $str or $str = $buf.decode: 'latin-1';
                $str = ($left-overs//'') ~ $str;

                (my $events, $left-overs) = self!parse: $str, :$server;
                $!event-pipe.send: $_ for $events.grep: *.defined;

                CATCH { default { warn $_; warn .backtrace } }
            }
        }

        unless $server.has-quit {
            $server.is-connected = False;
            $!debug and debug-print "Connection closed", :in, :$server;
            sleep 10;
        }

        $!socket-pipe.send: $server;
        CATCH { default { warn $_; warn .backtrace; } }
    }
}

method !handle-event ($e) {
    my $s = %!servers{ $e.server };
    given $e.command {
        when '001'  {
            $s.current-nick = $e.args[0];
            self.join: $s.channels, :server($s);
        }
        when 'PING'      { return $e.reply;      }
        when '433'|'432' { self!change-nick: $s; }
    }

    my $event-name = 'irc-' ~ $e.^name.subst('IRC::Client::Message::', '')
        .lc.subst: '::', '-', :g;

    my @events = flat gather {
        given $event-name {
            when 'irc-privmsg-channel' | 'irc-notice-channel' {
                my $nick    = $s.current-nick;
                my @aliases = $s.alias;
                if $e.text.subst-mutate:
                    /^ [ $nick | @aliases ] <[,:]> \s* /, ''
                {
                    take 'irc-addressed', ('irc-to-me' if $s.is-connected);
                }
                elsif $e.text ~~ / << [ $nick | @aliases ] >> /
                    and $s.is-connected
                {
                    take 'irc-mentioned';
                }
                take $event-name, $event-name eq 'irc-privmsg-channel'
                        ?? 'irc-privmsg' !! 'irc-notice';
            }
            when 'irc-privmsg-me' {
                take $event-name, ('irc-to-me' if $s.is-connected),
                    'irc-privmsg';
            }
            when 'irc-notice-me' {
                take $event-name, ('irc-to-me' if $s.is-connected),
                    'irc-notice';
            }
            when 'irc-mode-channel' | 'irc-mode-me' {
                take $event-name, 'irc-mode';
            }
            when 'irc-numeric' {
                if $e.command eq '001' {
                    $s.is-connected = True;
                    take 'irc-connected';
                }
                take 'irc-' ~ $e.command, $event-name;
            }
            default { take $event-name }
        }
        take 'irc-all';
    }

    EVENT: for @events -> $event {
        debug-print "emitting `$event`", :sys
            if $!debug >= 3 or ($!debug == 2 and not $event eq 'irc-all');

        for self!plugs-that-can($event, $e) {
            my $res is default(Nil) = ."$event"($e);
            next if $res ~~ IRC_FLAG_NEXT;

            # Do not .reply with bogus return values
            last EVENT if $res ~~ IRC::Client | Supply | Channel;

            if $res ~~ Promise {
                $res.then: {
                    $e.?reply: $^r.result
                        unless $^r.result ~~ Nil or $e.?replied;
                }
            } else {
                $e.?reply: $res unless $res ~~ Nil or $e.?replied;
            }
            last EVENT;

            CATCH { default { warn $_, .backtrace; } }
        }
    }
}

method !parse (Str:D $str, :$server) {
    return |IRC::Client::Grammar.parse(
        $str,
        :actions( IRC::Client::Grammar::Actions.new: :irc(self), :$server )
    ).made;
}

method !plugs-that-can ($method, |c) {
    gather {
        for @!plugins -> $plug {
            take $plug if .cando: \($plug, |c)
                for $plug.^can: $method;
        }
    }
}

method !get-server ($server is copy) {
    $server //= '_'; # stupid Perl 6 and its sig defaults
    return $server if $server ~~ IRC::Client::Server;
    return %!servers{$server};
}

method send-cmd ($cmd, *@args is copy, :$prefix = '', :$server) {
    if $cmd eq 'NOTICE'|'PRIVMSG' {
        my ($where, $text) = @args;
        if @!filters
            and my @f = @!filters.grep({
                   .signature.ACCEPTS: \($text)
                or .signature.ACCEPTS: \($text, :$where)
            })
        {
            start {
                CATCH { default { warn $_; warn .backtrace } }
                for @f -> $f {
                    given $f.signature.params.elems {
                        when 1 {           $text = $f($text);          }
                        when 2 { ($text, $where) = $f($text, :$where); }
                    }
                }
                self!ssay: :$server, join ' ', $cmd, $where, ":$prefix$text";
            }
        }
        else {
            self!ssay: :$server, join ' ', $cmd, $where, ":$prefix$text";
        }
    }
    else {
        @args[*-1] = ':' ~ @args[*-1] if @args;
        self!ssay: :$server, join ' ', $cmd, @args;
    }
}

method !set-server-attr ($server, $method, $what) {
    if $server ne '*' {
        %!servers{$server}."$method"() = $what ~~ List ?? @$what !! $what;
        return;
    }

    for %!servers.values {
        ."$method"() = $what ~~ List ?? @$what !! $what ;
    }
}

method !ssay (Str:D $msg, :$server is copy) {
    $server //= '*';
    $!debug and debug-print $msg, :out, :$server;
    %!servers{$_}.socket.print: "$msg\n"
        for |($server eq '*' ?? %!servers.keys.sort !! ~$server);
    self;
}

###############################################################################
###############################################################################
###############################################################################
###############################################################################
###############################################################################
###############################################################################

sub debug-print ($str, :$in, :$out, :$sys, :$server) {
    my $server-str = $server
        ?? colored(~$server, 'bold white on_cyan') ~ ' ' !! '';

    my @bits = (
        $str ~~ IRC::Client::Message::Privmsg|IRC::Client::Message::Notice
        ?? ":$str.usermask() $str.command() $str.args()[]"
        !! $str.Str
    ).split: ' ';

    if $in {
        my ($pref, $cmd) = 0, 1;
        if @bits[0] eq '❚⚠❚' {
            @bits[0] = colored @bits[0], 'bold white on_red';
            $pref++; $cmd++;
        }
        @bits[$pref] = colored @bits[$pref], 'bold magenta';
        @bits[$cmd] = (@bits[$cmd]//'') ~~ /^ <[0..9]>**3 $/
            ?? colored(@bits[$cmd]//'', 'bold red')
            !! colored(@bits[$cmd]//'', 'bold yellow');
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
