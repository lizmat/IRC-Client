unit class IRC::Client::Grammar::Actions:ver<3.009990>:auth<cpan:ELIZABETH>;

use IRC::Client::Message;

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

    my $pref := $match<prefix>;
    %args<who>{$_} = ~$pref{$_}
      for qw/nick user host/.grep: { $pref{$_}.defined }
    %args<who><host> = ~$pref<servername> if $pref<servername>.defined;

    my $p := $match<params>;
    loop {
        %args<params>.append: ~$p<middle> if $p<middle>.defined;

        with $p<trailing> {
            %args<params>.append: ~$_;
            last;
        }
        last unless $p<params>.defined;
        $p := $p<params>;
    }

    my %msg-args =
        command  => $match<command>.uc,
        args     => %args<params>,
        host     => %args<who><host>//'',
        irc      => $!irc,
        nick     => %args<who><nick>//'',
        server   => $!server,
        usermask => ~($match<prefix>//''),
        username => %args<who><user>//'';

    my $msg;
    my @params := %args<params>;
    given %msg-args<command> {
        when 'PRIVMSG' {
            my $channel := @params[0];
            $msg := $channel.starts-with('#') || $channel.starts-with('&')
              ?? IRC::Client::Message::Privmsg::Channel.new(
                   :$channel, :text(@params[1]), |%msg-args)
              !! IRC::Client::Message::Privmsg::Me.new(
                   :text(@params[1]), |%msg-args);
        }
        when 'PING' {
            $msg := IRC::Client::Message::Ping.new(|%msg-args);
        }
        when 'JOIN' {
            $msg := IRC::Client::Message::Join.new(
              :channel(@params[0]), |%msg-args);
        }
        when 'PART' {
            $msg := IRC::Client::Message::Part.new(
              :channel(@params[0] ), |%msg-args);
        }
        when 'NICK' {
            $msg := IRC::Client::Message::Nick.new(
              :new-nick(@params[0]), |%msg-args);
        }
        when 'NOTICE' {
            my $channel := @params[0];
            $msg := $channel.starts-with('#') || $channel.starts-with('&')
              ?? IRC::Client::Message::Notice::Channel.new(
                   :$channel, :text(@params[1]), |%msg-args)
              !! IRC::Client::Message::Notice::Me.new(
                   :text(@params[1]), |%msg-args);
        }
        when 'MODE' { 
            my $channel := @params[0];
            my $mode    := @params[1];
            $msg := $channel.starts-with('#') || $channel.starts-with('&')
              ?? IRC::Client::Message::Mode::Channel.new(
                   :$channel, :$mode, :nicks(@params.skip(2)), |%msg-args)
              !! IRC::Client::Message::Mode::Me.new(
                   :$mode, :nicks(@params.skip(2)), |%msg-args);
        }
        when 'TOPIC' {
            $msg := IRC::Client::Message::Topic.new(
              :channel(@params[0]), :text(@params[1]), |%msg-args);
        }
        when 'QUIT' {
            $msg := IRC::Client::Message::Quit.new(|%msg-args);
        }
        default {
            $msg := .chars == 3 && try 0 <= .Int <= 999
              ?? IRC::Client::Message::Numeric.new(|%msg-args)
              !! IRC::Client::Message::Unknown.new(|%msg-args);
        }
    }

    $match.make($msg)
}

# vim: expandtab shiftwidth=4
