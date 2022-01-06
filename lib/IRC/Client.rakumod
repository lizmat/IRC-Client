use IO::Socket::Async::SSL:ver<0.7.9>;
unit class IRC::Client:ver<4.0.7>:auth<zef:lizmat>;

my &colored;  # debug message coloring logic
my &debug;    # actual live debugging logic

my constant default-ping-wait = 300;
my subset Port of Int where 0 <= $_ <= 65535;

#-------------------------------------------------------------------------------
# IRC::Client::Server

class Server {
    has      $.irc;
    has      @.channels where .all ~~ Str|Pair;
    has      @.nick     where .all ~~ Str;
    has      @.alias    where .all ~~ Str|Regex;
    has Port $.port;
    has Bool $.ssl = False;
    has Str  $.ca-file;
    has Str  $.label;
    has Str  $.host;
    has Str  $.password;
    has Str  $.username;
    has Str  $.userhost;
    has Str  $.userreal;
    has Str  $.current-nick is rw;
    has Bool $.is-connected is rw;
    has Bool $.has-quit     is rw;
    has      $.socket       is rw;
    has Int  $!last-ping;
    has Int  $!ping-wait;

    method label() {
        $!label eq '_' ?? "$!host:$!port" !! $!label
    }

    method set-ping-wait(--> Nil) {
        $!ping-wait = time - $!last-ping without $!ping-wait;
    }

    method cue-next-ping-check($in? is copy --> Nil) {
        with $in {
            $!ping-wait = Nil;
        }
        else {
            $in = $!ping-wait
              ?? $!ping-wait + 10
              !! default-ping-wait;
        }

        my $seen-ping = $!last-ping = time;
        debug
          "Scheduling next PING test for {
              DateTime.new($seen-ping + $in)
          } (in $in seconds)",
          :sys, :server(self.label);
        $*SCHEDULER.cue: {
            if $!last-ping == $seen-ping {
                debug
                  "NO PING received after { DateTime.new($seen-ping) }",
                  :sys, :server(self.label);
                $!irc.reconnect-server(self)
            }
            else {
                debug
                  "PING received on {
                      DateTime.new($!last-ping)
                  } (after {
                    $!last-ping - $seen-ping
                  } seconds)",
                  :sys, :server(self.label);
            }
        }, :$in;
    }

    method Str { $!label }
}

#-------------------------------------------------------------------------------
# IRC::Client::Message

role Message { ... }

role Message::Join    does Message { has $.channel  }
role Message::Mode    does Message { has $.mode     }
role Message::Nick    does Message { has $.new-nick }
role Message::Numeric does Message {                }
role Message::Part    does Message { has $.channel  }
role Message::Quit    does Message {                }

role Message::Ping does Message {
    method reply() {
        $.server.set-ping-wait;
        $.irc.send-cmd: 'PONG', $.args, :$.server
    }
}

role Message::Mode::Channel does Message::Mode {
    has $.channel;
    has $.nicks;
}
role Message::Mode::Me does Message::Mode {
}

role Message::Privmsg does Message {
    has      $.text    is rw;
    has Bool $.replied is rw = False;
    method Str() { $.text }
}

role Message::Privmsg::Channel does Message::Privmsg {
    has $.channel;
    method reply($text, :$where) {
        $.irc.autoprefix
          ?? $.irc.send-cmd: 'PRIVMSG', $where // $.channel, $text, :$.server, :prefix("$.nick, ")
          !! $.irc.send-cmd: 'PRIVMSG', $where // $.channel, $text, :$.server
    }
}

role Message::Privmsg::Me does Message::Privmsg {
    method reply($text, :$where) {
        $.irc.send-cmd: 'PRIVMSG', $where // $.nick, $text,
            :$.server;
    }
}

role Message::Notice does Message {
    has      $.text    is rw;
    has Bool $.replied is rw = False;
    method Str() { $.text }
    method match($v) { $.text ~~ $v }
}

role Message::Notice::Channel does Message::Notice {
    has $.channel;
    method reply($text, :$where) {
        $.irc.autoprefix
          ?? $.irc.send-cmd: 'NOTICE', $where // $.channel, $text, :$.server, :prefix("$.nick, ")
          !! $.irc.send-cmd: 'NOTICE', $where // $.channel, $text, :$.server ;

        $.replied = True;
    }
}

role Message::Notice::Me does Message::Notice {
    method reply($text, :$where) {
        $.irc.send-cmd: 'NOTICE', $where // $.nick, $text,
            :$.server;
        $.replied = True;
    }
}

role Message::Topic does Message {
    has $.text is rw;
    has $.channel;
    method Str() { $.text }
    method match($v) { $.text ~~ $v }
}

role Message::Unknown does Message {
    method Str { "❚⚠❚ :$.usermask $.command $.args[]" }
}

role Message {
    has        $.irc      is required;
    has Str    $.nick     is required;
    has Str    $.username is required;
    has Str    $.host     is required;
    has Str    $.usermask is required;
    has Str    $.command  is required;
    has Server $.server   is required;
    has        $.args     is required;

    method Str { ":$!usermask $!command $!args[]" }
}

#-------------------------------------------------------------------------------
# IRC::Client::Grammar

grammar Grammar {

    token TOP { <message>+ <left-overs> }
    token left-overs { \N* }
    token SPACE { ' '+ }
    token message { [':' <prefix> <SPACE> ]? <command> <params> \n }

    regex prefix  {
        [ <servername> || <nick> ['!' <user>]? ['@' <host>]? ]
        <before <SPACE>>
    }
        token servername { <host> }
        token nick {
            # the RFC grammar states nicks have to start with a letter,
            # however, modern server support and nick use disagrees with that
            # and nicks can start with special chars too
            [<letter> | <special>] [ <letter> | <number> | <special> ]*
        }
        token user { <-[\ \x[0]\r\n]>+?  <before [<SPACE> | '@']>}
        token host { <-[\s!@]>+ }

    token command { <letter>+ | <number>**3 }

    token params { <SPACE>* [ ':' <trailing> | <middle> <params> ]? }
        token middle { <-[:\ \x[0]\r\n]> <-[\ \x[0]\r\n]>* }
        token trailing { <-[\x[0]\r\n]>* }

    token letter { <[a..zA..Z]> }
    token number { <[0..9]> }
    token special { <[-_\[\]\\`^{}|]> }
}

#-------------------------------------------------------------------------------
# IRC::Client::Actions

class Actions {
    has $.irc;
    has $.server;

    method TOP($/) {
        $/.make: (
            $<message>».made,
            ~( $<left-overs> // '' ),
        );
    }

    method message($match) {
        my %args;

        my %who; %who := .hash with %args<who>;
        with $match<prefix> {
            my %pref := .hash;
            %who{$_} = %pref{$_}.Str
              for qw/nick user host/.grep: { %pref{$_}.defined }
            %who<host> = .Str with %pref<servername>;
        }

        with $match<params> {
            my %params := .hash;
            loop {
                %args<params>.append: .Str with %params<middle>;

                with %params<trailing> {
                    %args<params>.append: .Str;
                    last;
                }
                last without %params<params>;
                %params := %params<params>.hash;
            }
        }

        my %msg-args =
            command  => $match<command>.uc,
            args     => %args<params>,
            host     => %who<host> // '',
            irc      => $!irc,
            nick     => %who<nick> // '',
            server   => $!server,
            usermask => ($match<prefix> // '').Str,
            username => %who<user> // '';

        my @params := %args<params>;
        $match.make: do given %msg-args<command> {
            when 'PRIVMSG' {
                my $channel := @params[0];
                $channel.starts-with('#') || $channel.starts-with('&')
                  ?? IRC::Client::Message::Privmsg::Channel.new(
                       :$channel, :text(@params[1]), |%msg-args)
                  !! IRC::Client::Message::Privmsg::Me.new(
                       :text(@params[1]), |%msg-args)
            }
            when 'PING' {
                IRC::Client::Message::Ping.new(|%msg-args)
            }
            when 'JOIN' {
                IRC::Client::Message::Join.new(
                  :channel(@params[0]), |%msg-args)
            }
            when 'PART' {
                IRC::Client::Message::Part.new(
                  :channel(@params[0] ), |%msg-args)
            }
            when 'NICK' {
                IRC::Client::Message::Nick.new(
                  :new-nick(@params[0]), |%msg-args)
            }
            when 'NOTICE' {
                my $channel := @params[0];
                $channel.starts-with('#') || $channel.starts-with('&')
                  ?? IRC::Client::Message::Notice::Channel.new(
                       :$channel, :text(@params[1]), |%msg-args)
                  !! IRC::Client::Message::Notice::Me.new(
                       :text(@params[1]), |%msg-args)
            }
            when 'MODE' { 
                my $channel := @params[0];
                my $mode    := @params[1];
                $channel.starts-with('#') || $channel.starts-with('&')
                  ?? IRC::Client::Message::Mode::Channel.new(
                       :$channel, :$mode, :nicks(@params.skip(2)), |%msg-args)
                  !! IRC::Client::Message::Mode::Me.new(
                       :$mode, :nicks(@params.skip(2)), |%msg-args)
            }
            when 'TOPIC' {
                IRC::Client::Message::Topic.new(
                  :channel(@params[0]), :text(@params[1]), |%msg-args)
            }
            when 'QUIT' {
                IRC::Client::Message::Quit.new(|%msg-args)
            }
            default {
                .chars == 3 && try 0 <= .Int <= 999
                  ?? IRC::Client::Message::Numeric.new(|%msg-args)
                  !! IRC::Client::Message::Unknown.new(|%msg-args)
            }
        }
    }
}

#-------------------------------------------------------------------------------
# IRC::Client

my class IRC_FLAG_NEXT {};
role Plugin {
    my IRC_FLAG_NEXT $.NEXT;
    has $.irc is rw;
}

my class Reconnector does Plugin {
    has $.magic-word is required;
    method irc-to-me($_) {
        .text eq $!magic-word
          ?? .irc.reconnect-server(.server)
          !! $.NEXT
    }
}

has Callable @.filters;
has          @.plugins;
has Server   %.servers     is built(False);
has Lock     $!lock        is built(:bind) = Lock.new;
has Channel  $!event-pipe  is built(:bind) = Channel.new;
has Channel  $!socket-pipe is built(:bind) = Channel.new;
has Bool     $.autoprefix  is built(:bind) = True;
has Int      $.debug       is built(False);

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
         :$debug     = 0,
         :$magic-word,
--> Nil) {
    my %all-conf =
      :$port,     :$password, :$host,     :$nick,     :@alias,
      :$username, :$userhost, :$userreal, :$channels, :$ssl,   :$ca-file;

    $!debug := $debug.Int;
    without &debug {
        if $!debug {
            &colored = (try require Terminal::ANSIColor) === Nil
              ?? -> Str $s, $ { $s }
              !! ::('Terminal::ANSIColor::EXPORT::DEFAULT::&colored');
            &debug = &debug-print;
            debug "Activated debugging level $!debug", :sys;
        }
        else {
            &debug = -> | --> Nil { }
        }
    }

    @!plugins.unshift: Reconnector.new(magic-word => $_) with $magic-word;

    %servers = '_' => {} unless %servers;
    for %servers.kv -> $label, %conf {
        my @nick = |(%conf<nick> // %all-conf<nick>);
        my $s := Server.new(
          :irc(self),
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
}

method reconnect-server($server --> Nil) {
    debug "Reconnecting $server.label()", :$server, :sys;
    $server.socket.close;
}

method join(*@channels, :$server --> IRC::Client:D) {
    self.send-cmd: 'JOIN', ($_ ~~ Pair ?? .kv !! .Str), :$server, :dont-cue
      for @channels;
    self
}

method nick(*@nicks, :$server = '*' --> IRC::Client:D) {
    default-expansion-nicks(@nicks) if @nicks == 1;
    self!set-server-attr($server, 'nick', @nicks);
    self!set-server-attr($server, 'current-nick', @nicks[0]);
    self.send-cmd: 'NICK', @nicks[0], :$server, :dont-cue;
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
    self.send-cmd: 'QUIT', :$server, :dont-cue;
    self
}

method run(--> Nil) {
    .irc = self for @.plugins.grep: { .DEFINITE and .^can: 'irc' };

    start {
        my $closed = $!event-pipe.closed;
        loop {
            if $!event-pipe.receive -> $e {
                debug $e, :in, :server($e.server);
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
            debug 'All servers quit by user. Exiting', :sys;
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
            debug
              ".send() called for an unconnected server. Skipping...",
              :out, :server($_);
        }
    }

    self
}

#-------------------------------------------------------------------------------
# Private Methods

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
    debug 'Attempting to connect to server', :out, :$server;

    my $socket := try $server.ssl
      ?? IO::Socket::Async::SSL.connect(
           $server.host,
           $server.port,
           ca-file => $server.ca-file
         )
      !! IO::Socket::Async.connect($server.host, $server.port);

    with $socket {
        $socket.then: sub ($prom) {
            if $prom.status ~~ Broken {
                $server.is-connected = False;
                debug "Could not connect: $prom.cause()", :out, :$server;
                sleep 10;
                $!socket-pipe.send: $server;
                return;
            }

            $server.socket = $prom.result;
            $server.cue-next-ping-check(default-ping-wait);

            self!ssay: "PASS $server.password()", :$server, :dont-cue
                if $server.password.defined;
            self!ssay: "NICK {$server.nick[0]}", :$server, :dont-cue;

            self!ssay: :$server, :dont-cue, join ' ', 'USER', $server.username,
                $server.username, $server.host, ':' ~ $server.userreal;

            my $left-overs = '';
            react {
                whenever $server.socket.Supply :bin -> $buf is copy {
                    my $str = try $buf.decode: 'utf8';
                    $str or $str = $buf.decode: 'latin-1';
                    $str = $left-overs ~ $str if $left-overs;

                    (my $events, $left-overs) = self!parse: $str, :$server;
                    $!event-pipe.send: $_ for $events.grep: *.defined;

                    CATCH { default { warn $_; warn .backtrace; done } }
                }
            }

            unless $server.has-quit {
                $server.is-connected = False;
                debug "Connection closed", :in, :$server;
                sleep 1;
            }

            $!socket-pipe.send: $server;
            CATCH { default { warn $_; warn .backtrace; } }
        }
    }
    else {
        debug "Connection to $server.alias() failed: $!", :sys, :$server;
        sleep 10;
        $!socket-pipe.send: $server;
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
              and $s.is-connected {
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
        debug("emitting `$event`", :sys)
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
      :actions( IRC::Client::Actions.new: :irc(self), :$server )
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

method send-cmd(
  $cmd, *@args is copy, :$prefix = '', :$server, :$dont-cue
--> Nil) {
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
                self!ssay: :$server, :$dont-cue,
                  join ' ', $cmd, $where, ":$prefix$text";
            }
        }
        else {
            self!ssay: :$server, :$dont-cue,
              join ' ', $cmd, $where, ":$prefix$text";
        }
    }
    else {
        if @args {
            my $last := @args[*-1];
            $last = ':' ~ $last
                if not $last or $last.starts-with: ':' or $last.match: /\s/;
        }
        self!ssay: :$server, :$dont-cue,
          join ' ', $cmd, @args;
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

method !ssay(Str:D $msg, :$server is copy, :$dont-cue) {
    $server //= '*';
    debug $msg, :out, :$server;
    for |($server eq '*' ?? %!servers.keys.sort !! ~$server) {
        with %!servers{$_} {
            .socket.print: "$msg\n";
            .cue-next-ping-check unless $dont-cue;
        }
    }
    self
}

#-------------------------------------------------------------------------------
# Debugging

sub debug-print($str, :$in, :$out, :$sys, :$server --> Nil) {
    my $server-str = $server
      ?? colored(~$server, 'bold white on_cyan') ~ ' '
      !! '';

    my @bits = (
        $str ~~ Message::Privmsg | Message::Notice | Message::Topic
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
        put colored('▬▬▶ ', 'bold blue' )
          ~ (DateTime.now.Str.substr(11,8) ~ ' '
              if $str ~~ IRC::Client::Message::Ping)
          ~ $server-str
          ~ @bits.join: ' ';
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

=begin pod

=head1 NAME

IRC::Client - Extendable Internet Relay Chat client

=head1 SYNOPSIS

=begin code :lang<raku>

use IRC::Client;
use Pastebin;

.run with IRC::Client.new:
    :host<irc.libera.chat>
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
* [Basics Tutorial](https://github.com/lizmat/IRC-Client/blob/main/docs/01-basics.md)
* [Event Reference](https://github.com/lizmat/IRC-Client/blob/main/docs/02-event-reference.md)
* [Method Reference](https://github.com/lizmat/IRC-Client/blob/main/docs/03-method-reference.md)
* [Big-Picture Behaviour](https://github.com/lizmat/IRC-Client/blob/main/docs/04-big-picture-behaviour.md)
* [Examples](https://github.com/lizmat/IRC-Client/blob/main/examples/)

=head1 AUTHORS

=item Zoffix Znet (2015-2018)
=item Elizabeth Mattijsen (2021-) <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/IRC-Client . Comments and
Pull Requests are welcome.

=head1 CONTRIBUTORS

=item Daniel Green
=item Patrick Spek

=head1 COPYRIGHT AND LICENSE

Copyright 2015-2021 Zoffix Znet
Copyright 2021 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

The C<META6.json> file of this distribution may be distributed and modified without restrictions or attribution.

=end pod

# vim: expandtab shiftwidth=4
