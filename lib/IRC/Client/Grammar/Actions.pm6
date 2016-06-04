unit class IRC::Client::Grammar::Actions;

use IRC::Client::Message::Numeric;

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
        if ( $p<middle>.defined ) {
            %args<params>.append: ~$p<middle>;
        }
        if ( $p<trailing>.defined ) {
            %args<params>.append: ~$p<trailing>;
            last;
        }
        last unless $p<params>.defined;
        $p = $p<params>;
    }

    my %msg-args =
        irc      => $!irc,
        nick     => %args<who><nick>//'',
        username => %args<who><user>//'',
        host     => %args<who><host>//'',
        server   => $!server;
    .<usermask> = .<nick> ~ '!' ~ .<username> ~ '@' ~ .<host> given %msg-args;

    my $msg;
    given ~$match<command> {
        when /^ $<command>=(<[0..9]>**3) $/ {
            $msg = IRC::Client::Message::Numeric.new:
                :command( ~$<command> ),
                :args( %args<params> ),
                |%msg-args;
        }
    }

    $match.make: $msg;
}
