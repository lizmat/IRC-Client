unit package IRC::Client::Message:ver<4.0.0>:auth<zef:lizmat>;

role IRC::Client::Message {
    has       $.irc      is required;
    has Str:D $.nick     is required;
    has Str:D $.username is required;
    has Str:D $.host     is required;
    has Str:D $.usermask is required;
    has Str:D $.command  is required;
    has       $.server   is required;
    has       $.args     is required;

    method Str { ":$!usermask $!command $!args[]" }
}

constant M = IRC::Client::Message;

role Join          does M    { has $.channel;              }
role Mode          does M    { has $.mode;                 }
role Mode::Channel does Mode { has $.channel; has $.nicks; }
role Mode::Me      does Mode {                             }
role Nick          does M    { has $.new-nick;             }
role Numeric       does M    {                             }
role Part          does M    { has $.channel;              }
role Quit          does M    {                             }
role Unknown       does M    {
    method Str { "❚⚠❚ :$.usermask $.command $.args[]" }
}

role Ping does M {
    method reply() { $.irc.send-cmd: 'PONG', $.args, :$.server; }
}

role Privmsg does M {
    has      $.text    is rw;
    has Bool $.replied is rw = False;
    method Str() { $.text }
}
role Privmsg::Channel does Privmsg {
    has $.channel;
    method reply($text, :$where) {
        $.irc.autoprefix
          ?? $.irc.send-cmd: 'PRIVMSG', $where // $.channel, $text, :$.server, :prefix("$.nick, ")
          !! $.irc.send-cmd: 'PRIVMSG', $where // $.channel, $text, :$.server
    }
}
role Privmsg::Me does Privmsg {
    method reply($text, :$where) {
        $.irc.send-cmd: 'PRIVMSG', $where // $.nick, $text,
            :$.server;
    }
}

role Notice does M {
    has      $.text    is rw;
    has Bool $.replied is rw = False;
    method Str() { $.text }
    method match($v) { $.text ~~ $v }
}
role Notice::Channel does Notice {
    has $.channel;
    method reply($text, :$where) {
        $.irc.autoprefix
          ?? $.irc.send-cmd: 'NOTICE', $where // $.channel, $text, :$.server, :prefix("$.nick, ")
          !! $.irc.send-cmd: 'NOTICE', $where // $.channel, $text, :$.server ;

        $.replied = True;
    }
}
role Notice::Me does Notice {
    method reply($text, :$where) {
        $.irc.send-cmd: 'NOTICE', $where // $.nick, $text,
            :$.server;
        $.replied = True;
    }
}

role Topic does M {
    has $.text is rw;
    has $.channel;
    method Str() { $.text }
    method match($v) { $.text ~~ $v }
}

# vim: expandtab shiftwidth=4
