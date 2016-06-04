unit class IRC::Client::Grammar::Actions;

use IRC::Client::Message::Numeric;

has $.irc;
has $.server;

method TOP ($/) { $/.make: ($<message>».made, $<left-overs>) }

method left-overs ($/) {
    $/.made: $/.defined ?? !$/ !! '';
}

method message ($/) {
    my %args;
    my $pref = $/<prefix>;
    for qw/nick user host/ {
        $pref{$_}.defined or next;
        %args<who>{$_} = ~$pref{$_};
    }
    %args<who><host> = ~$pref<servername> if $pref<servername>.defined;

    my $p = $<params>;

    loop {
        if ( $p<middle>.defined ) {
            %args<params>.append: ~$p<middle>;
        }
        if ( $p<trailing>.defined ) {
            %args<params>.append: ~$p<trailing>;
            last;
        }
        $p = $p<params>;
    }

    my %msg-args =
        irc      => $!irc,
        nick     => %args<who><nick>,
        username => %args<who><user>,
        host     => %args<who><host>,
        usermask => "%args<who><nick>!%args<who><user>@%args<who><host>",
        server   => $!server;

    my $msg;
    given ~$<command> {
        when /^ ([0..9]**3) $/ {
            $msg = IRC::Client::Message::Numeric.new:
                :command( $<command> ),
                :args( %args<params> ),
                |%msg-args;
        }
    }

    $/.make: $msg;
}
