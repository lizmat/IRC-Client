unit class IRC::Client::Grammar::Actions:ver<3.009990>:auth<cpan:ELIZABETH>;

use IRC::Client::Message;

has $.irc;
has $.server;

method TOP ($/) {
    $/.make: (
        $<message>».made,
        ~( $<left-overs> // '' ),
    );
}

method message ($match) {
    my %args;
    my $pref = $match<prefix>;
    for qw/nick user host/ {
        $pref{$_}.defined or next;
        %args<who>{$_} = ~$pref{$_};
    }
    %args<who><host> = ~$pref<servername> if $pref<servername>.defined;

    my $p = $match<params>;
    loop {
        %args<params>.append: ~$p<middle> if $p<middle>.defined;

        if ( $p<trailing>.defined ) {
            %args<params>.append: ~$p<trailing>;
            last;
        }
        last unless $p<params>.defined;
        $p = $p<params>;
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
    given %msg-args<command> {
        when /^ <[0..9]>**3 $/ {
            $msg = IRC::Client::Message::Numeric.new: |%msg-args;
        }
        when 'JOIN' {
            $msg = IRC::Client::Message::Join.new:
                :channel( %args<params>[0] ),
                |%msg-args;
        }
        when 'PART' {
            $msg = IRC::Client::Message::Part.new:
                :channel( %args<params>[0] ),
                |%msg-args;
        }
        when 'NICK'    {
            $msg = IRC::Client::Message::Nick.new:
                :new-nick( %args<params>[0] ),
                |%msg-args;
        }
        when 'NOTICE'  { $msg = msg-notice  %args, %msg-args                  }
        when 'MODE'    { $msg = msg-mode    %args, %msg-args                  }
        when 'PING'    { $msg = IRC::Client::Message::Ping.new: |%msg-args    }
        when 'PRIVMSG' { $msg = msg-privmsg %args, %msg-args                  }
        when 'QUIT'    { $msg = IRC::Client::Message::Quit.new: |%msg-args    }
        default        { $msg = IRC::Client::Message::Unknown.new: |%msg-args }
    }

    $match.make: $msg;
}

sub msg-privmsg (%args, %msg-args) {
    %args<params>[0] ~~ /^<[#&]>/
        and return IRC::Client::Message::Privmsg::Channel.new:
            :channel( %args<params>[0] ),
            :text( %args<params>[1] ),
            |%msg-args;

    return IRC::Client::Message::Privmsg::Me.new:
        :text( %args<params>[1] ),
        |%msg-args;
}

sub msg-notice (%args, %msg-args) {
    %args<params>[0] ~~ /^<[#&]>/
        and return IRC::Client::Message::Notice::Channel.new:
            :channel( %args<params>[0] ),
            :text( %args<params>[1] ),
            |%msg-args;

    return IRC::Client::Message::Notice::Me.new:
        :text( %args<params>[1] ),
        |%msg-args;
}

sub msg-mode (%args, %msg-args) {
    my @params := %args<params>;
    if @params[0] ~~ /^<[#&]>/ {
        return IRC::Client::Message::Mode::Channel.new:
            :channel( @params[0] ),
            :mode( @params[1] ),
            :nicks( @params.skip(2) ),
            |%msg-args;
    }
    else {
        return IRC::Client::Message::Mode::Me.new:
            :mode( @params[1] ),
            :nicks( @params.skip(2) ),
            |%msg-args;
    }
}
