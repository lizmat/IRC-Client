
use IO::Socket::Async::SSL;

use IRC::Client::Message:ver<3.009990>:auth<cpan:ELIZABETH>;
use IRC::Client::Grammar:ver<3.009990>:auth<cpan:ELIZABETH>;
use IRC::Client::Server:ver<3.009990>:auth<cpan:ELIZABETH>;
use IRC::Client::Grammar::Actions:ver<3.009990>:auth<cpan:ELIZABETH>;

my &colored;  # debug message coloring logic

subset Port of Int where 0 <= $_ <= 65535;

my class IRC_FLAG_NEXT {};
role IRC::Client::Plugin {
    my IRC_FLAG_NEXT $.NEXT;
    has $.irc is rw;
}

class IRC::Client:ver<3.009990>:auth<cpan:ELIZABETH> {
    has Callable            @.filters;
    has                     @.plugins;
    has IRC::Client::Server %.servers is built(False);
    has Int     $.debug       is built(:bind) = 0;
    has Lock    $!lock        is built(:bind) = Lock.new;
    has Channel $!event-pipe  is built(:bind) = Channel.new;
    has Channel $!socket-pipe is built(:bind) = Channel.new;
    has Bool    $.autoprefix  is built(:bind) = True;

    # Automatically add nick__ variants if given just one nick
    sub default-expansion-nicks(\nicks) {
        my $nick = nicks.head;
        nicks.push: ($nick ~= '_') for ^3;
    }

    submethod TWEAK(
             :%servers is copy,
             :@alias,
      Str    :$password,
      Str    :$ca-file,
      Port   :$port      = 6667,
      Str:D  :$host      = 'localhost',
             :$nick      = ['RakuBot'],
      Bool:D :$ssl       = False,
      Str:D  :$username  = 'RakuIRC',
      Str:D  :$userhost  = 'localhost',
      Str:D  :$userreal  = "Raku {self.^name} v{self.^ver}",
             :$channels  = ('#raku',),
    --> Nil) {
        my %all-conf =
          :$port,     :$password, :$host,     :$nick,     :@alias,
          :$username, :$userhost, :$userreal, :$channels, :$ssl,   :$ca-file;

        %servers = '_' => {} unless %servers;
        for %servers.kv -> $label, %conf {
            my @nick = |(%conf<nick> // %all-conf<nick>);
            my $s := IRC::Client::Server.new(
                :socket(Nil),
                :$label,
                :channels( @(%conf<channels> // %all-conf<channels>) ),
                :@nick,
                :alias[ |(%conf<alias> // %all-conf<alias>) ],
                |%(
                    <host password port username userhost userreal ssl ca-file>
                        .map: { $_ => %conf{$_} // %all-conf{$_} }
                ),
            );

            # Automatically add nick__ variants if given just one nick
            default-expansion-nicks($s.nick) if @nick == 1;
            $s.current-nick = @nick[0];
            %!servers{$label} := $s;
        }

        # Coloring only needed when running in debug mode
        if $!debug {
            &colored = (try require Terminal::ANSIColor) === Nil
              ?? -> Str $s, $ { $s }
              !! ::('Terminal::ANSIColor::EXPORT::DEFAULT::&colored');
        }
    }

    method join(*@channels, :$server --> IRC::Client:D) {
        self.send-cmd: 'JOIN', ($_ ~~ Pair ?? .kv !! .Str), :$server
          for @channels;
        self
    }

    method nick(*@nicks, :$server = '*' --> IRC::Client:D) {
        default-expansion-nicks(@nicks) if @nicks == 1;
        self!set-server-attr($server, 'nick', @nicks);
        self!set-server-attr($server, 'current-nick', @nicks[0]);
        self.send-cmd: 'NICK', @nicks[0], :$server;
        self
    }

    method part(*@channels, :$server --> IRC::Client:D) {
        self.send-cmd: 'PART', $_, :$server for @channels;
        self
    }

    method quit(:$server = '*' --> IRC::Client:D) {
        if $server eq '*' {
            .has-quit = True for %!servers.values;
        }
        else {
            self!get-server($server).has-quit = True;
        }
        self.send-cmd: 'QUIT', :$server;
        self
    }

    method run(--> Nil) {
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
                elsif $closed {
                    last;
                }
            }
            CATCH { default { warn $_; warn .backtrace } }
        }

        .irc-started for self!plugins-that-can('irc-started');
        self!connect-socket: $_ for %!servers.values;

        loop {
            my $s := $!socket-pipe.receive;
            self!connect-socket: $s unless $s.has-quit;
            unless %!servers.grep(!*.value.has-quit) {
                $!debug and debug-print 'All servers quit by user. Exiting', :sys;
                last;
            }
        }
    }

    method send(:$where!, :$text!, :$server, :$notice --> IRC::Client:D) {
        for $server || |%!servers.keys.sort {
            if self!get-server($_).is-connected {
                self.send-cmd: $notice ?? 'NOTICE' !! 'PRIVMSG', $where, $text,
                    :server($_);
            }
            else {
                $!debug and debug-print( :out, :server($_),
                    '.send() called for an unconnected server. Skipping...'
                );
            }
        }

        self
    }

###############################################################################

    method !change-nick($server --> Nil) {
        my int $idx = 0;
        for $server.nick.kv -> int $i, $nick {
            if $nick ne $server.current-nick {
                $idx = $i + 1;
                $idx = 0 if $idx == $server.nick.elems;
                last;
            }
        };

        sub set-nick(--> Nil) {
            $server.current-nick = my $nick := $server.nick[$idx];
            self.send-cmd: "NICK $nick", :$server;
        }
        $idx
          ?? set-nick()
          !! Promise.in(10).then: &set-nick;
    }

    method !connect-socket($server --> Nil) {
        $!debug and debug-print 'Attempting to connect to server', :out, :$server;

        my $socket := $server.ssl
          ?? IO::Socket::Async::SSL.connect(
               $server.host,
               $server.port,
               ca-file => $server.ca-file
             )
          !! IO::Socket::Async.connect($server.host, $server.port);

        $socket.then: sub ($prom) {
            if $prom.status ~~ Broken {
                $server.is-connected = False;
                $!debug and debug-print "Could not connect: $prom.cause()", :out, :$server;
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

    method !handle-event($e) {
        my $s := %!servers{$e.server};
        given $e.command {
            when '001'  {
                $s.current-nick = $e.args[0];
                self.join: $s.channels, :server($s);
            }
            when 'PING'      { return $e.reply;      }
            when '433'|'432' { self!change-nick: $s; }
        }

        my $event-name = 'irc-'
          ~ $e.^name.subst('IRC::Client::Message::', '').lc.subst: '::','-',:g;

        my str @events;
        sub add(*@names) { @events.append: @names }

        given $event-name {
            when 'irc-privmsg-channel' | 'irc-notice-channel' {
                my $nick    = $s.current-nick;
                my @aliases = $s.alias;
                if $e.text ~~ s/^ [ $nick | @aliases ] <[,:]> \s*// {
                    add 'irc-addressed',
                        ('irc-to-me' if $s.is-connected);
                }
                elsif $e.text ~~ / << [ $nick | @aliases ] >> /
                    and $s.is-connected
                {
                    add 'irc-mentioned';
                }
                add $event-name,
                    $event-name eq 'irc-privmsg-channel'
                      ?? 'irc-privmsg'
                      !! 'irc-notice';
            }
            when 'irc-privmsg-me' {
                add $event-name,
                    ('irc-to-me' if $s.is-connected),
                    'irc-privmsg';
            }
            when 'irc-notice-me' {
                add $event-name,
                    ('irc-to-me' if $s.is-connected),
                    'irc-notice';
            }
            when 'irc-mode-channel' | 'irc-mode-me' {
                add $event-name, 'irc-mode';
            }
            when 'irc-numeric' {
                if $e.command eq '001' {
                    $s.is-connected = True;
                    add 'irc-connected';
                }

                # prefix numerics with 'n' as irc-\d+ isn't a valid identifier
                add 'irc-'
                  ~ ('n' if $e ~~ IRC::Client::Message::Numeric)
                  ~ $e.command,
                  $event-name;
            }
            default { add $event-name }
        }
        add 'irc-all';

        EVENT:
        for @events -> $event {
            debug-print "emitting `$event`", :sys
                if $!debug >= 3 or ($!debug == 2 and not $event eq 'irc-all');

            for self!plugins-that-can($event, $e) {
                my $res is default(Nil) = ."$event"($e);
                next if $res ~~ IRC_FLAG_NEXT;

                # Do not .reply with bogus return values
                last EVENT if $res ~~ IRC::Client | Supply | Channel;

                if $res ~~ Promise {
                    $res.then: {
                        $e.?reply: $^r.result
                            unless $^r.result ~~ Nil or $e.?replied;
                    }
                }
                else {
                    $e.?reply: $res unless $res ~~ Nil or $e.?replied;
                }
                last EVENT;

                CATCH { default { warn $_, .backtrace; } }
            }
        }
    }

    method !parse(Str:D $str, :$server) {
        |IRC::Client::Grammar.parse(
          $str,
          :actions( IRC::Client::Grammar::Actions.new: :irc(self), :$server )
        ).made
    }

    method !plugins-that-can($method, |c) {
        my @can;
        for @!plugins -> $plugin {
            for $plugin.^can($method) {
                @can.push: $plugin if .cando: \($plugin, |c)
            }
        }
        @can
    }

    method !get-server($server --> IRC::Client::Server:D) {
        with $server {
            $_ ~~ IRC::Client::Server ?? $_ !! %!servers{$_}
        }
        else {
            %!servers<_>
        }
    }

    method send-cmd($cmd, *@args is copy, :$prefix = '', :$server --> Nil) {
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
            if @args {
                my $last := @args[*-1];
                $last = ':' ~ $last
                    if not $last or $last.starts-with: ':' or $last.match: /\s/;
            }
            self!ssay: :$server, join ' ', $cmd, @args;
        }
    }

    method !set-server-attr($server, $method, $what --> Nil) {
        if $server eq '*' {
            for %!servers.values {
                ."$method"() = $what ~~ List ?? @$what !! $what ;
            }
        }
        else {
            %!servers{$server}."$method"() = $what ~~ List ?? @$what !! $what;
        }
    }

    method !ssay(Str:D $msg, :$server is copy) {
        $server //= '*';
        $!debug and debug-print $msg, :out, :$server;
        %!servers{$_}.socket.print: "$msg\n"
            for |($server eq '*' ?? %!servers.keys.sort !! ~$server);
        self
    }

###############################################################################

    sub debug-print($str, :$in, :$out, :$sys, :$server --> Nil) {
        my $server-str = $server
          ?? colored(~$server, 'bold white on_cyan') ~ ' '
          !! '';

        my @bits = (
            $str ~~
              IRC::Client::Message::Privmsg
              | IRC::Client::Message::Notice
              | IRC::Client::Message::Topic
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
            put colored(' ' x 4 ~ '↳', 'bold white')
              ~ ' '
              ~ @bits.join(' ')
                  .subst: /(\`<-[`]>+\`)/, { colored(~$0, 'bold cyan') };
        }
        else {
            die "Unknown debug print mode";
        }
    }
}

=begin pod

=head1 NAME

IRC::Client - Extendable Internet Relay Chat client

=head1 SYNOPSIS

=begin code :lang<raku>

use IRC::Client;
use Pastebin;

.run with IRC::Client.new:
    :host<irc.freenode.net>
    :channels<#rakubot #zofbot>
    :debug
    :plugins(
        class { method irc-to-me ($ where /hello/) { 'Hello to you too!'} }
    )
    :filters(
        -> $text where .chars > 200 {
            'The output is too large to show here. See: '
            ~ Pastebin.new.paste: $text;
        }
    );

=end code

=head1 DESCRIPTION

The module provides the means to create clients to communicate with
IRC (Internet Relay Chat) servers. Has support for non-blocking responses
and output post-processing.

=head1 DOCUMENTATION MAP

* [Blog Post](https://github.com/Raku/CCR/blob/main/Remaster/Zoffix%20Znet/IRC-Client-Raku-Multi-Server-IRC-or-Awesome-Async-Interfaces-with-Raku.md)
* [Basics Tutorial](docs/01-basics.md)
* [Event Reference](docs/02-event-reference.md)
* [Method Reference](docs/03-method-reference.md)
* [Big-Picture Behaviour](docs/04-big-picture-behaviour.md)
* [Examples](examples/)

=head1 AUTHORS

=item Zoffix Znet (2015-2018)
=item Elizabeth Mattijsen (2021-) <liz@wenzperl.nl>

Source can be located at: https://github.com/lizmat/IRC-Client . Comments and
Pull Requests are welcome.

=head1 CONTRIBUTORS

=item Daniel Green
=item Patrick Spek

=head1 COPYRIGHT AND LICENSE

Copyright 2015-2021 Zoffix Znet, Copyright 2021 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

The C<META6.json> file of this distribution may be distributed and modified without restrictions or attribution.

=end pod

# vim: expandtab shiftwidth=4
